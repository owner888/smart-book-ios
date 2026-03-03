package widget

import (
	"embed"
	"log/slog"
	"os"
	"path"
	"strings"

	"github.com/dop251/goja"
	"github.com/dop251/goja_nodejs/require"
)

func Enable(vm *goja.Runtime, dir string) error {
	jsFile := path.Join(dir, "index.js")
	_, err := vm.RunScript(jsFile, `
    const widget = require('./widget.js');
    for (const key of Object.keys(widget)) {
        this[key] = widget[key];
    }
    `)
	if err != nil {
		slog.Error("load widget", "name", dir, "err", err)
		return err
	}
	slog.Info("load widget", "name", dir)
	return nil
}

func BuiltinSourceLoader(name string) ([]byte, error) {
	return require.DefaultSourceLoader(name)
}

func EmbedSourceLoader(e embed.FS, name string) ([]byte, error) {
	data, err := e.ReadFile(name)
	if os.IsNotExist(err) {
		return []byte{}, require.ModuleFileDoesNotExistError
	}
	if err != nil && strings.Contains(err.Error(), "is a directory") {
		return []byte{}, require.ModuleFileDoesNotExistError
	}
	return data, err
}
