package event

import "github.com/dop251/goja"

func Enable(vm *goja.Runtime) (func(string, ...string) error, error) {
	listeners := map[string]func(...string){}
	err := vm.Set("addEventListener", func(event string, listener func(data ...string)) {
		listeners[event] = listener
	})
	if err != nil {
		return nil, err
	}
	err = vm.Set("removeEventListener", func(event string, listener func(data ...string)) {
		delete(listeners, event)
	})
	if err != nil {
		return nil, err
	}
	return func(event string, data ...string) error {
		if f, ok := listeners[event]; ok {
			f(data...)
		}
		return On(vm, event)
	}, nil
}

func On(vm *goja.Runtime, event string) error {
	fn := "on" + event
	_, err := vm.RunString(fn + " && " + fn + "()")
	return err
}

type Listener func(Event)

type Event struct {
	Type string `json:"type,omitempty"`
}

type MessageEvent struct {
	Event
	Data any `json:"data,omitempty"`
}

type CloseEvent struct {
	Event
	Code     int    `json:"code,omitempty"`
	Reason   string `json:"reason,omitempty"`
	WasClean bool   `json:"wasClean,omitempty"`
}

type ErrorEvent struct {
	Event
	Message string `json:"message,omitempty"`
	Error   error  `json:"error,omitempty"`
}