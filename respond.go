package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	g "github.com/gorilla/handlers"
	gormux "github.com/gorilla/mux"
	"github.com/justinas/alice"
)

func getenvironment(data []string, getkeyval func(item string) (key, val string)) map[string]string {
	items := make(map[string]string)
	for _, item := range data {
		key, val := getkeyval(item)
		items[key] = val
	}
	return items
}

func init() {

	//print out all environment variables on machine0
	environment := getenvironment(os.Environ(), func(item string) (key, val string) {
		splits := strings.Split(item, "=")
		key = splits[0]
		val = splits[1]
		return
	})

	for k, v := range environment {
		log.Println("key =", k, " value = ", v)
	}

}

func main() {
	httpServer()
}

func healthValidatorHandler(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.ServeHTTP(w, r)
	})
}

//WrapHTTPHandler to capture status code, wrapping handler
type WrapHTTPHandler struct {
	m http.Handler
}

func (h *WrapHTTPHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	lw := &loggedResponse{ResponseWriter: w, status: 200}

	elapsed := callServer(h, lw, r)

	log.Printf("ServeHTTP [%s] %s - %d in %s\n", r.RemoteAddr, r.URL, lw.status, elapsed.String())
}

type loggedResponse struct {
	http.ResponseWriter
	status int
}

func (l *loggedResponse) WriteHeader(status int) {
	l.status = status
	l.ResponseWriter.WriteHeader(status)
}

//created to measure duration of call to ServeHTTP
func callServer(h *WrapHTTPHandler, lw *loggedResponse, r *http.Request) (elapsed time.Duration) {
	start := time.Now()

	defer func() {
		elapsed = time.Since(start)
	}()

	h.m.ServeHTTP(lw, r)

	return elapsed
}

func httpServer() {
	r := gormux.NewRouter()

	port0 := os.Getenv("PORT0")

	if _, err := strconv.Atoi(port0); err != nil {
		log.Fatalf("Failed to retrieve PORT0: %s", err.Error())
	}

	//used to capture status code and write log
	var wrapper = &WrapHTTPHandler{m: http.StripPrefix("/", http.FileServer(http.Dir("static")))}
	chain := alice.New(g.CompressHandler, healthValidatorHandler).Then(wrapper)
	r.PathPrefix("/").Handler(chain)
	err := http.ListenAndServe(fmt.Sprintf(":%s", port0), r)

	log.Fatalf("Failed to start http server: %s", err.Error())

}
