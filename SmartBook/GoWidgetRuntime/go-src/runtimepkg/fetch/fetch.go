package fetch

import (
	"bytes"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/textproto"

	"github.com/dop251/goja"
	"github.com/dop251/goja_nodejs/eventloop"
)

func Enable(loop *eventloop.EventLoop, proxy http.Handler) error {
	if proxy == nil {
		return fmt.Errorf("proxy handler cannot be nil")
	}

	loop.RunOnLoop(func(vm *goja.Runtime) {
		_ = vm.Set("__fetch__", request(loop, proxy))
		_, err := vm.RunString(`
(function(){
  function makeResponse(r){
    return {
      ok: r.status >= 200 && r.status < 300,
      status: r.status,
      headers: r.headers || {},
      url: r.url || '',
      text: function(){ return Promise.resolve(String(r.body || '')); },
      json: function(){ return Promise.resolve(JSON.parse(String(r.body || 'null'))); },
      arrayBuffer: function(){ return Promise.resolve(r.bytes || []); }
    };
  }
  this.fetch = function(url, opts){
    return new Promise(function(resolve, reject){
      try {
        __fetch__(String(url), opts || {}, function(resp){ resolve(makeResponse(resp)); });
      } catch (e) {
        reject(e);
      }
    });
  };
})();`)
		if err != nil {
			panic(err)
		}
	})
	return nil
}

func request(loop *eventloop.EventLoop, proxy http.Handler) func(call goja.FunctionCall) goja.Value {
	return func(call goja.FunctionCall) goja.Value {
		if fn, ok := goja.AssertFunction(call.Argument(2)); ok {
			u := call.Argument(0).String()
			o := map[string]any{}
			if arg := call.Argument(1); !goja.IsUndefined(arg) && !goja.IsNull(arg) {
				if exported, ok := arg.Export().(map[string]any); ok {
					o = exported
				}
			}
			go func() {
				defer func() {
					if r := recover(); r != nil {
						slog.Error("fetch", "panic", fmt.Sprintf("panic: %v", r))
					}
				}()

				var body io.Reader
				method := http.MethodGet
				header := make(http.Header)
				if headers, ex := o["headers"]; ex {
					if hmap, okh := headers.(map[string]any); okh {
						for key, value := range hmap {
							if arr, ok := value.([]any); ok {
								var items []string
								for _, item := range arr {
									if s, ok := item.(string); ok {
										items = append(items, s)
									}
								}
								header[textproto.CanonicalMIMEHeaderKey(key)] = items
							} else if s, ok := value.(string); ok {
								header[textproto.CanonicalMIMEHeaderKey(key)] = []string{s}
							}
						}
					}
				}
				if b, ex := o["body"]; ex {
					if bo, ok := b.(string); ok {
						body = bytes.NewBufferString(bo)
					} else if bo, ok := b.([]byte); ok {
						body = bytes.NewBuffer(bo)
					}
				}
				if m, ex := o["method"]; ex {
					if me, ok := m.(string); ok {
						method = me
					}
				}

				res := httptest.NewRecorder()
				req, err := http.NewRequest(method, u, body)
				var toRet map[string]any
				if err != nil {
					toRet = map[string]any{
						"url":     u,
						"method":  method,
						"status":  http.StatusInternalServerError,
						"headers": map[string][]string{},
						"body":    fmt.Sprintf("Internal Server Error: %s", err.Error()),
					}
				} else {
					req.Header = header
					proxy.ServeHTTP(res, req)
					toRet = map[string]any{
						"url":     u,
						"method":  method,
						"status":  res.Code,
						"headers": map[string][]string(res.Header()),
						"body":    res.Body.String(),
						"bytes":   res.Body.Bytes(),
					}
				}

				loop.RunOnLoop(func(vm *goja.Runtime) {
					_, _ = fn(nil, vm.ToValue(toRet))
				})
			}()
		}
		return nil
	}
}
