package crypto

import (
	"bytes"
	"io"
	"log/slog"
	"runtime/debug"

	"github.com/andybalholm/brotli"
	"github.com/dop251/goja"
	"github.com/dop251/goja_nodejs/require"
)

const ModuleName = "brotli"

func init() {
	require.RegisterCoreModule(ModuleName, BrotliModule)
}

func BrotliModule(runtime *goja.Runtime, m *goja.Object) {
	o := m.Get("exports").(*goja.Object)
	o.Set("compress", func(call goja.FunctionCall) (ret goja.Value) {
		defer func() {
			if err2 := recover(); err2 != nil {
				if ret == nil {
					ret = goja.Undefined()
				}
				slog.Error("brotli compress failed", "panic", err2, "stack", debug.Stack())
			}
		}()
		data, ok := call.Argument(0).Export().([]byte)
		if !ok {
			return goja.Undefined()
		}
		var b bytes.Buffer
		writer := brotli.NewWriter(&b)
		_, err := writer.Write(data)
		if err != nil {
			return goja.Undefined()
		}
		writer.Close()
		return runtime.ToValue(b.Bytes())
	})

	o.Set("decompress", func(call goja.FunctionCall) (ret goja.Value) {
		defer func() {
			if err2 := recover(); err2 != nil {
				if ret == nil {
					ret = goja.Undefined()
				}
				slog.Error("brotli decompress failed", "panic", err2, "stack", debug.Stack())
			}
		}()
		data, ok := call.Argument(0).Export().([]byte)
		if !ok {
			return goja.Undefined()
		}
		reader := brotli.NewReader(bytes.NewReader(data))
		decompressedData, err := io.ReadAll(reader)
		if err != nil {
			return goja.Undefined()
		}
		return runtime.ToValue(decompressedData)
	})
}

func Enable(vm *goja.Runtime) error {
	m := require.Require(vm, ModuleName).ToObject(vm)
	return vm.Set(ModuleName, m)
}
