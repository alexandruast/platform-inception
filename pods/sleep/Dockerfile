FROM golang:alpine as BUILDER

WORKDIR /go/src/go-app

COPY . .

RUN go build ./

FROM scratch

COPY --from=BUILDER /go/src/go-app/go-app  /go-app

CMD ["go-app"]