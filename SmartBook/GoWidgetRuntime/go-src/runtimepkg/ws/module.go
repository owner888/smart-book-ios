package ws

import (
	"reflect"

	"github.com/dop251/goja"
	"github.com/dop251/goja_nodejs/errors"
	"github.com/dop251/goja_nodejs/require"
)

const ModuleName = "ws"

func init() {
	require.RegisterCoreModule(ModuleName, Require)
}

func Enable(vm *goja.Runtime) error {
	m := require.Require(vm, ModuleName).ToObject(vm)
	return vm.Set("WebSocket", m.Get("WebSocket"))
}

func Require(runtime *goja.Runtime, module *goja.Object) {
	ws := &wsModule{r: runtime}
	ctor := runtime.ToValue(ws.constructor).ToObject(runtime)
	o := module.Get("exports").(*goja.Object)
	_ = o.Set("WebSocket", ctor)
}

type wsModule struct {
	r *goja.Runtime
}

func (b *wsModule) constructor(call goja.ConstructorCall) (res *goja.Object) {
	return b._from(call.Arguments...)
}

func (b *wsModule) _from(args ...goja.Value) *goja.Object {
	if len(args) == 0 {
		panic(errors.NewTypeError(b.r, errors.ErrCodeInvalidArgType, "The first argument must be of type string"))
	}
	arg := args[0]
	var url = ""
	if arg != nil && arg.ExportType() != nil {
		switch arg.ExportType().Kind() {
		case reflect.String:
			url = arg.String()
		}
	}
	return b.r.ToValue(New(url, "")).(*goja.Object)
}
