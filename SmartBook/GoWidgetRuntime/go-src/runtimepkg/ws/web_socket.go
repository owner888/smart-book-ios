package ws

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"

	"gowidgetruntime/runtimepkg/event"

	"github.com/coder/websocket"
)

type WebSocket struct {
	Url       string `json:"url,omitempty"`
	Protocol  string `json:"protocol,omitempty"`
	protocols string
	Onopen    func(event.Event)
	Onclose   func(event.CloseEvent)
	Onmessage func(event.MessageEvent)
	Onerror   func(event.ErrorEvent)

	conn   *websocket.Conn
	cancel context.CancelFunc
}

func New(url string, protocols string) *WebSocket {
	ws := &WebSocket{Url: url}
	go ws.connect()
	return ws
}

func (w *WebSocket) Send(data any) {
	var t websocket.MessageType
	if w.conn != nil {
		var b []byte
		switch d := data.(type) {
		case string:
			b = []byte(d)
			t = websocket.MessageText
		case []byte:
			b = d
			t = websocket.MessageBinary
		default:
			j, err := json.Marshal(data)
			if err != nil {
				w.error(err)
				return
			}
			b = j
			t = websocket.MessageText
		}
		w.error(w.conn.Write(context.Background(), t, b))
	}
}

func (w *WebSocket) Close() {
	if w.conn == nil {
		return
	}
	if w.cancel != nil {
		w.cancel()
	}
	err := w.conn.CloseNow()
	if err != nil {
		w.error(err)
		return
	}
	if w.Onclose != nil {
		w.Onclose(event.CloseEvent{Event: event.Event{Type: "close"}})
	}
}

func (w *WebSocket) connect() {
	defer func() {
		if err := recover(); err != nil {
			slog.Warn("websocket connect error", "err", err)
		}
	}()
	ctx := context.Background()
	c, _, err := websocket.Dial(ctx, w.Url, &websocket.DialOptions{
		Subprotocols: []string{w.protocols},
		HTTPClient:   &http.Client{Transport: transport("")},
		HTTPHeader:   http.Header{"User-Agent": []string{"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"}},
	})
	if err != nil {
		w.error(err)
		return
	}
	w.conn = c
	if w.Onopen != nil {
		w.Onopen(event.Event{Type: "open"})
	}
	ctx, w.cancel = context.WithCancel(ctx)
	go w.read(ctx)
}

func (w *WebSocket) read(ctx context.Context) {
	defer func() {
		if err := recover(); err != nil {
			slog.Warn("websocket read error", "err", err)
		}
	}()
	errTimes := 0
	for {
		t, d, err := w.conn.Read(ctx)
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, net.ErrClosed) || errors.Is(err, io.EOF) {
				break
			}
			if errTimes > 3 {
				break
			}
			errTimes++
			w.error(err)
			time.Sleep(time.Second)
			continue
		}
		errTimes = 0
		var data any = d
		if t == websocket.MessageText {
			data = string(d)
		}
		if w.Onmessage != nil {
			w.Onmessage(event.MessageEvent{Event: event.Event{Type: "message"}, Data: data})
		}
	}
}

func (w *WebSocket) error(err error) {
	if err != nil && w.Onerror != nil {
		w.Onerror(event.ErrorEvent{Event: event.Event{Type: "error"}, Error: err, Message: err.Error()})
	}
}

func transport(dns string) http.RoundTripper {
	tp := http.DefaultTransport.(*http.Transport).Clone()
	tp.MaxResponseHeaderBytes = 262144
	tp.DialContext = (&net.Dialer{Timeout: 5 * time.Second, KeepAlive: 5 * time.Second, Resolver: resolver(dns)}).DialContext
	tp.IdleConnTimeout = 5 * time.Second
	tp.TLSHandshakeTimeout = 5 * time.Second
	tp.TLSClientConfig = &tls.Config{CipherSuites: []uint16{tls.TLS_RSA_WITH_RC4_128_SHA, tls.TLS_RSA_WITH_3DES_EDE_CBC_SHA, tls.TLS_RSA_WITH_AES_128_CBC_SHA, tls.TLS_RSA_WITH_AES_256_CBC_SHA, tls.TLS_RSA_WITH_AES_128_CBC_SHA256, tls.TLS_RSA_WITH_AES_128_GCM_SHA256, tls.TLS_RSA_WITH_AES_256_GCM_SHA384, tls.TLS_ECDHE_ECDSA_WITH_RC4_128_SHA, tls.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA, tls.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA, tls.TLS_ECDHE_RSA_WITH_RC4_128_SHA, tls.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA, tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA, tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA, tls.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256, tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256, tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256, tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256, tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384, tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384, tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256, tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256, tls.TLS_AES_128_GCM_SHA256, tls.TLS_AES_256_GCM_SHA384, tls.TLS_CHACHA20_POLY1305_SHA256}}
	return tp
}

func resolver(ns string) *net.Resolver {
	if ns == "" {
		return net.DefaultResolver
	}
	if _, _, ok := strings.Cut(ns, ":"); !ok {
		ns += ":53"
	}
	return &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
		d := net.Dialer{Timeout: 5000 * time.Millisecond}
		return d.DialContext(ctx, network, ns)
	}}
}
