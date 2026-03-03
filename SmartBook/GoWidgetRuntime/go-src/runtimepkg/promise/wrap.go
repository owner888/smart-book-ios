package promise

import (
	"encoding/json"
	"errors"
	"log/slog"
	"reflect"

	"github.com/dop251/goja"
)

type Promise func(v goja.Value, then func(value goja.Value), catch func(err *goja.Object)) error

type promise struct {
	err     error
	value   string
	fulfill func(string)
	reject  func(error)
}

func Enable(vm *goja.Runtime) (Promise, error) {
	const js = `function __invoke_wrap__(v, thenFn, catchFn) {
        Promise.resolve(v).then(thenFn).catch(catchFn);
    }`
	_, err := vm.RunString(js)
	if err != nil {
		return nil, err
	}
	var fn Promise
	err = vm.ExportTo(vm.Get("__invoke_wrap__"), &fn)
	if err != nil {
		return nil, err
	}
	if fn == nil {
		return nil, errors.New("failed to enable promise")
	}
	return fn, nil
}

func (p *promise) Then(f func(value string)) *promise {
	p.fulfill = f
	if p.value != "" {
		f(p.value)
	}
	return p
}

func (p *promise) Catch(f func(err error)) *promise {
	p.reject = f
	if p.err != nil {
		f(p.err)
	}
	return p
}

func New(fn Promise, v goja.Value, err error) *promise {
	p := &promise{err: err}
	if err != nil {
		return p
	}
	err = fn(v, func(value goja.Value) {
		var out []byte
		var marshalErr error
		var kind reflect.Kind
		if value != nil && value.ExportType() != nil {
			kind = value.ExportType().Kind()
		}
		switch kind {
		case reflect.String:
			out = []byte(value.String())
		default:
			out, marshalErr = json.Marshal(value)
		}
		if marshalErr != nil {
			p.err = marshalErr
			if p.reject != nil {
				p.reject(p.err)
			}
			return
		}
		p.value = string(out)
		if p.fulfill != nil {
			p.fulfill(p.value)
		}
	}, func(errObj *goja.Object) {
		slog.Warn("runtime error", "stack", errObj.Get("stack"))
		p.err = errors.New(errObj.String())
		if p.reject != nil {
			p.reject(p.err)
		}
	})
	if err != nil {
		p.err = err
		slog.Error("promise", "err", err)
	}
	return p
}
