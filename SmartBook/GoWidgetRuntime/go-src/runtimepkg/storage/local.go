package storage

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"os"
	"path"

	"github.com/dop251/goja"
)

func Enable(vm *goja.Runtime, p string) error {
	reader := func(f string) io.ReadWriteSeeker {
		if p == "" {
			return nil
		}
		return getReader(f)
	}

	if err := vm.Set("localStorage", New(vm, reader(path.Join(p, ".storage")))); err != nil {
		return err
	}
	if err := vm.Set("sessionStorage", New(vm, nil)); err != nil {
		return err
	}
	if err := vm.Set("widgetStorage", New(vm, reader(path.Join(p, "storage")))); err != nil {
		return err
	}
	if err := vm.Set("sharedStorage", New(vm, reader(path.Join(path.Dir(p), ".storage")))); err != nil {
		return err
	}
	return nil
}

func getReader(p string) io.ReadWriteSeeker {
	if p == "" {
		return nil
	}
	store, err := os.OpenFile(p, os.O_RDWR|os.O_CREATE, 0o666)
	if err != nil {
		slog.Error("storage", "err", err, "path", p)
		return nil
	}
	return store
}

type Storage struct {
	data   map[string]any
	vm     *goja.Runtime
	rw     io.ReadWriteSeeker
	Length int
}

func New(vm *goja.Runtime, rw io.ReadWriteSeeker) *Storage {
	m := make(map[string]any)
	if rw != nil {
		if err := json.NewDecoder(rw).Decode(&m); err != nil {
			if !errors.Is(err, io.EOF) {
				slog.Error("read local storage wrong", "err", err)
			}
		}
	}
	return &Storage{vm: vm, rw: rw, data: m}
}

func (s *Storage) Key(index int) string {
	i := 0
	for k := range s.data {
		if i == index {
			return k
		}
		i++
	}
	return ""
}

func (s *Storage) GetItem(keyName string) any {
	if v, ok := s.data[keyName]; ok {
		return v
	}
	return goja.Undefined()
}

func (s *Storage) SetItem(keyName string, keyValue any) {
	s.data[keyName] = keyValue
	s.Length = len(s.data)
	s.save()
}

func (s *Storage) RemoveItem(keyName string) {
	delete(s.data, keyName)
	s.save()
}

func (s *Storage) Clear() {
	clear(s.data)
	s.save()
}

func (s *Storage) save() {
	if s.rw == nil {
		return
	}
	if rw, ok := s.rw.(interface{ Truncate(size int64) error }); ok {
		_ = rw.Truncate(0)
		_, _ = s.rw.Seek(0, io.SeekStart)
	}
	if err := json.NewEncoder(s.rw).Encode(s.data); err != nil {
		slog.Error("save local storage wrong", "err", err)
	}
}
