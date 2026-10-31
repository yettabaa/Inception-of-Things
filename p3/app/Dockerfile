# Multi-arch build (amd64 + arm64):
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     --build-arg VERSION=v1 -t <dockerhub-user>/playground:v1 --push p3/app
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS TARGETARCH VERSION=dev
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -ldflags "-s -w -X main.version=$VERSION" -o /playground main.go

FROM scratch
COPY --from=build /playground /playground
EXPOSE 8888
ENTRYPOINT ["/playground"]
