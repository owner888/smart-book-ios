package main

/*
#include <stdlib.h>
#include <stdint.h>

typedef void (*widget_event_cb)(int64_t handle, const char* event, const char* message, void* user_data);

static inline void wr_emit_event(widget_event_cb cb, int64_t handle, const char* event, const char* message, void* user_data) {
	if (cb != NULL) {
		cb(handle, event, message, user_data);
	}
}
*/
import "C"

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	neturl "net/url"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"

	"gowidgetruntime/runtimepkg/crypto"
	"gowidgetruntime/runtimepkg/event"
	"gowidgetruntime/runtimepkg/fetch"
	"gowidgetruntime/runtimepkg/message"
	"gowidgetruntime/runtimepkg/promise"
	"gowidgetruntime/runtimepkg/storage"
	gojaWidget "gowidgetruntime/runtimepkg/widget"
	"gowidgetruntime/runtimepkg/ws"

	"github.com/dop251/goja"
	"github.com/dop251/goja_nodejs/buffer"
	"github.com/dop251/goja_nodejs/eventloop"
	"github.com/dop251/goja_nodejs/require"
	gojaURL "github.com/dop251/goja_nodejs/url"
	"github.com/imroc/req/v3"
	"moul.io/http2curl/v2"
)

type runtimeEntry struct {
	handle   int64
	widget   *widgetRuntime
	eventCB  C.widget_event_cb
	userData unsafe.Pointer
}

type widgetRuntime struct {
	Path          string
	event         *eventBridge
	vm            *vmRuntime
	mux           sync.Mutex
	InitialScript string
}

type vmRuntime struct {
	*eventloop.EventLoop
	runtime *goja.Runtime
	Event   func(string, ...string) error
	Promise promise.Promise
}

type ffiResult struct {
	Code int         `json:"code"`
	Msg  string      `json:"msg"`
	Data any `json:"data"`
}

var (
	runtimeMux    sync.RWMutex
	runtimeSeq    int64 = 1000
	runtimeHandle       = map[int64]*runtimeEntry{}
	widgetRootDir string
	storeRootDir  string
)

func newVMRuntime(widgetsPath string, script string, on func(string, string)) (*vmRuntime, error) {
	vm := &vmRuntime{EventLoop: eventloop.NewEventLoop(eventloop.WithRegistry(require.NewRegistryWithLoader(gojaWidget.BuiltinSourceLoader)))}
	vm.EventLoop.Run(func(r *goja.Runtime) {
		vm.runtime = r
		r.SetFieldNameMapper(goja.UncapFieldNameMapper())
	})
	vm.EventLoop.Start()
	err := fetch.Enable(vm.EventLoop, doRequest(roundTripperFunc(autoRoundTripper)))
	if err != nil {
		return nil, err
	}
	wg := sync.WaitGroup{}
	wg.Add(1)
	vm.EventLoop.RunOnLoop(func(r *goja.Runtime) {
		defer wg.Done()
		buffer.Enable(r)
		gojaURL.Enable(r)
		err = message.Enable(r, func(data string) {
			if on != nil {
				on("message", data)
			}
		})
		if err != nil {
			return
		}
		vm.Event, err = event.Enable(r)
		if err != nil {
			return
		}
		p, err := promise.Enable(r)
		if err != nil {
			return
		}
		vm.Promise = p
		err = ws.Enable(r)
		if err != nil {
			return
		}
		err = storage.Enable(r, widgetsPath)
		if err != nil {
			return
		}
		err = crypto.Enable(r)
		if err != nil {
			return
		}
		if script != "" {
			_, err = r.RunString(script)
			if err != nil {
				return
			}
		}
		if widgetsPath != "" {
			err = gojaWidget.Enable(r, widgetsPath)
			if err != nil {
				return
			}
		}

		if err := vm.Event("load"); err != nil {
			slog.Debug("onload", "err", err)
		}
	})
	wg.Wait()
	if err != nil {
		return nil, err
	}
	return vm, nil
}

func (v *vmRuntime) Run(code string) (ret string, err error) {
	defer func() {
		if err2 := recover(); err2 != nil {
			err = fmt.Errorf("%v", err2)
		}
	}()
	wg := sync.WaitGroup{}
	wg.Add(1)
	v.EventLoop.RunOnLoop(func(r *goja.Runtime) {
		slog.Info("javascript", "status", "start", "script", code)
		value, runErr := r.RunString(code)
		promise.New(v.Promise, value, runErr).Then(func(value string) {
			out := value
			if len(out) > 200 {
				out = out[:100] + " ... " + out[len(out)-100:]
			}
			slog.Info("javascript", "status", "done", "result", out)
			ret = value
			wg.Done()
		}).Catch(func(e error) {
			slog.Warn("javascript", "status", "error", "err", e)
			err = e
			wg.Done()
		})
	})
	wg.Wait()
	return
}

func autoRoundTripper(r *http.Request) (*http.Response, error) {
	const fingerprintHeader = "X-Fingerprint"
	if fp := r.Header.Get(fingerprintHeader); fp != "" {
		r.Header.Del(fingerprintHeader)
		return reqRoundTripper(fp)(r)
	}
	return defaultRoundTripper(r)
}

func reqRoundTripper(browser string) func(r *http.Request) (*http.Response, error) {
	return func(r *http.Request) (*http.Response, error) {
		director(r)
		command, err := http2curl.GetCurlCommand(r)
		slog.Info("fetch", "command", command, "err", err)
		client := req.DevMode()
		switch browser {
		case "chrome":
			client.ImpersonateChrome()
		case "safari":
			client.ImpersonateSafari()
		case "firefox":
			client.ImpersonateFirefox()
		default:
			client.ImpersonateChrome()
		}
		req := client.NewRequest()
		req.Method = r.Method
		req.RawURL = r.URL.String()
		req.Headers = make(http.Header)
		for k, v := range r.Header {
			if _, ok := client.Headers[k]; !ok {
				req.Headers[k] = v
			}
		}
		resp := req.Do(r.Context())
		return resp.Response, resp.Err
	}
}

func defaultRoundTripper(r *http.Request) (*http.Response, error) {
	director(r)
	command, err := http2curl.GetCurlCommand(r)
	slog.Info("fetch", "command", command, "err", err)
	client := &http.Client{Transport: transport(getAndDeleteHeader(r, "X-DNS"), getDefaultAndDeleteHeader(r, "X-Proxy"))}
	return client.Do(r)
}

type roundTripperFunc func(r *http.Request) (*http.Response, error)

func (f roundTripperFunc) RoundTrip(r *http.Request) (*http.Response, error) {
	return f(r)
}

func doRequest(transport http.RoundTripper) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cloneReq := r.Clone(r.Context())
		resp, err := transport.RoundTrip(cloneReq)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to forward request: %v", err), http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()

		w.WriteHeader(resp.StatusCode)
		for key, values := range resp.Header {
			for _, value := range values {
				w.Header().Add(key, value)
			}
		}

		_, err = io.Copy(w, resp.Body)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to copy response body: %v", err), http.StatusInternalServerError)
		}
	})
}

func director(r *http.Request) {
	if ua := r.Header.Get("User-Agent"); strings.Contains(ua, "golang-fetch") {
		r.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
	}
	const timeoutHeader = "X-Timeout"
	if timeout := r.Header.Get(timeoutHeader); timeout != "" {
		r.Header.Del(timeoutHeader)
		if t, err := strconv.Atoi(timeout); err == nil {
			ctx, _ := context.WithTimeout(r.Context(), time.Duration(t)*time.Millisecond)
			*r = *r.WithContext(ctx)
		}
	}
}

func getAndDeleteHeader(r *http.Request, key string) string {
	value := r.Header.Get(key)
	r.Header.Del(key)
	return value
}

func getDefaultAndDeleteHeader(r *http.Request, key string) string {
	value := r.Header.Get(key)
	if _, ok := r.Header[key]; value == "" && ok {
		value = "none"
	}
	r.Header.Del(key)
	return value
}

var defaultProxy func(*http.Request) (*neturl.URL, error)

func transport(dns string, proxy string) http.RoundTripper {
	tp := http.DefaultTransport.(*http.Transport).Clone()
	tp.MaxResponseHeaderBytes = 262144
	tp.DialContext = (&net.Dialer{
		Timeout:   5 * time.Second,
		KeepAlive: 5 * time.Second,
		Resolver:  resolver(dns),
	}).DialContext
	tp.IdleConnTimeout = 5 * time.Second
	tp.TLSHandshakeTimeout = 10 * time.Second
	if proxy != "" {
		if proxy == "none" || proxy == "direct" {
			tp.Proxy = nil
		} else {
			tp.Proxy = func(r *http.Request) (*neturl.URL, error) {
				return neturl.Parse(proxy)
			}
		}
	} else {
		tp.Proxy = defaultProxy
	}
	return tp
}

func resolver(ns string) *net.Resolver {
	if ns == "" {
		return net.DefaultResolver
	}
	if _, _, ok := strings.Cut(ns, ":"); !ok {
		ns += ":53"
	}
	return &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			d := net.Dialer{Timeout: 5000 * time.Millisecond}
			return d.DialContext(ctx, network, ns)
		},
	}
}

func nextHandle() int64 {
	runtimeMux.Lock()
	defer runtimeMux.Unlock()
	runtimeSeq++
	return runtimeSeq
}

func putRuntime(entry *runtimeEntry) {
	runtimeMux.Lock()
	defer runtimeMux.Unlock()
	runtimeHandle[entry.handle] = entry
}

func getRuntime(handle int64) (*runtimeEntry, bool) {
	runtimeMux.RLock()
	defer runtimeMux.RUnlock()
	entry, ok := runtimeHandle[handle]
	return entry, ok
}

func removeRuntime(handle int64) (*runtimeEntry, bool) {
	runtimeMux.Lock()
	defer runtimeMux.Unlock()
	entry, ok := runtimeHandle[handle]
	if ok {
		delete(runtimeHandle, handle)
	}
	return entry, ok
}

func cStringToGo(v *C.char) string {
	if v == nil {
		return ""
	}
	return C.GoString(v)
}

func marshalResponse(code int, msg string, data interface{}) *C.char {
	payload, _ := json.Marshal(ffiResult{Code: code, Msg: msg, Data: data})
	return C.CString(string(payload))
}

type eventBridge struct {
	handle   int64
	eventCB  C.widget_event_cb
	userData unsafe.Pointer
}

func newWidgetRuntime(path string, event *eventBridge) (*widgetRuntime, error) {
	if path == "" {
		return nil, errors.New("empty widget path")
	}
	return &widgetRuntime{Path: path, event: event}, nil
}

func (w *widgetRuntime) Start(script string) error {
	w.mux.Lock()
	defer w.mux.Unlock()
	if script != "" {
		w.InitialScript = script
	}
	if w.vm != nil {
		return nil
	}
	vm, err := newVMRuntime(w.Path, w.InitialScript, w.event.On)
	if err != nil {
		return err
	}
	w.vm = vm
	return nil
}

func (w *widgetRuntime) Run(script string) (string, error) {
	if err := w.Start(""); err != nil {
		return "", err
	}
	if w.vm == nil {
		return "", errors.New("js runtime not initialized")
	}
	return w.vm.Run(script)
}

func (w *widgetRuntime) On(event string, payload ...string) error {
	if err := w.Start(""); err != nil {
		return err
	}
	if w.vm == nil {
		return errors.New("js runtime not initialized")
	}
	return w.vm.Event(event, payload...)
}

func (w *widgetRuntime) Stop() {
	w.mux.Lock()
	defer w.mux.Unlock()
	if w.vm == nil {
		return
	}
	w.vm.Stop()
	w.vm = nil
}

func (e *eventBridge) On(event string, message string) {
	if e == nil || e.eventCB == nil {
		return
	}
	cEvent := C.CString(event)
	cMessage := C.CString(message)
	defer C.free(unsafe.Pointer(cEvent))
	defer C.free(unsafe.Pointer(cMessage))
	C.wr_emit_event(e.eventCB, C.int64_t(e.handle), cEvent, cMessage, e.userData)
}

//export wr_init
func wr_init(widgetDir *C.char, dataDir *C.char) C.int32_t {
	widgetRootDir = cStringToGo(widgetDir)
	storeRootDir = cStringToGo(dataDir)
	return 0
}

//export wr_create
func wr_create(widgetPath *C.char, cb C.widget_event_cb, userData unsafe.Pointer) C.int64_t {
	handle := nextHandle()
	bridge := &eventBridge{handle: handle, eventCB: cb, userData: userData}
	widget, err := newWidgetRuntime(cStringToGo(widgetPath), bridge)
	if err != nil {
		return 0
	}
	putRuntime(&runtimeEntry{handle: handle, widget: widget, eventCB: cb, userData: userData})
	return C.int64_t(handle)
}

//export wr_destroy
func wr_destroy(handle C.int64_t) {
	entry, ok := removeRuntime(int64(handle))
	if !ok || entry == nil || entry.widget == nil {
		return
	}
	entry.widget.Stop()
}

//export wr_start
func wr_start(handle C.int64_t, initialScript *C.char) C.int32_t {
	entry, ok := getRuntime(int64(handle))
	if !ok || entry.widget == nil {
		return -1
	}
	if err := entry.widget.Start(cStringToGo(initialScript)); err != nil {
		return -2
	}
	return 0
}

//export wr_stop
func wr_stop(handle C.int64_t) C.int32_t {
	entry, ok := getRuntime(int64(handle))
	if !ok || entry.widget == nil {
		return -1
	}
	entry.widget.Stop()
	return 0
}

//export wr_run
func wr_run(handle C.int64_t, script *C.char) *C.char {
	entry, ok := getRuntime(int64(handle))
	if !ok || entry.widget == nil {
		return marshalResponse(-1, "invalid runtime handle", nil)
	}
	result, err := entry.widget.Run(cStringToGo(script))
	if err != nil {
		return marshalResponse(-2, err.Error(), nil)
	}

	var jsonData interface{}
	if json.Unmarshal([]byte(result), &jsonData) == nil {
		return marshalResponse(0, "ok", jsonData)
	}
	return marshalResponse(0, "ok", result)
}

//export wr_on
func wr_on(handle C.int64_t, event *C.char, payload *C.char) C.int32_t {
	entry, ok := getRuntime(int64(handle))
	if !ok || entry.widget == nil {
		return -1
	}
	if err := entry.widget.On(cStringToGo(event), cStringToGo(payload)); err != nil {
		return -2
	}
	return 0
}

//export wr_string_free
func wr_string_free(p *C.char) {
	if p == nil {
		return
	}
	C.free(unsafe.Pointer(p))
}

func main() {}
