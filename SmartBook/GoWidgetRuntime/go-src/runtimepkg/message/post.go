package message

import "github.com/dop251/goja"

func Enable(vm *goja.Runtime, on func(data string)) error {
	return vm.Set("postMessage", func(data string) { on(data) })
}
