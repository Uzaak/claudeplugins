# Golang Standards — Code Examples

All snippets below are non-executable reference examples illustrating the rules in SKILL.md.

## Domain Module (bootstrap.go / controller.go / service.go)

```go
// bootstrap.go
func Bootstrap(router *gin.Engine) {
    group := router.Group("/orders")
    group.GET("/:id", GetOrder)
    group.POST("/", CreateOrder)
}

// controller.go
func GetOrder(ctx *gin.Context) {
    result, err := service.GetOrder(ctx.Request.Context(), ctx.Param("id"))
    if err != nil {
        ctx.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
        return
    }
    ctx.JSON(http.StatusOK, result)
}

// service.go
func GetOrder(ctx context.Context, id string) (Response, error) {
    logrus.WithContext(ctx).Debug("get order")
    // business logic
    return Response{}, nil
}
```

## Gin Configuration

```go
gin.SetMode(gin.ReleaseMode)       // production
router := gin.New()
router.HandleMethodNotAllowed = true
// Set NoRoute and NoMethod handlers returning JSON
router.NoRoute(func(c *gin.Context) {
    c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
})
```

## Logging — logrus

```go
import "github.com/sirupsen/logrus"

// Always use WithContext for trace propagation
logrus.WithContext(ctx).Info("processing order")
logrus.WithContext(ctx).WithField("order_id", id).Debug("fetching order")

// Standard fields
// timestamp, message, caller — set JSON formatter globally
logrus.SetFormatter(&logrus.JSONFormatter{})
```

## Configuration — envconfig (/configs/envs.go)

```go
package configs

import "github.com/kelseyhightower/envconfig"

type Config struct {
    Port           int    `env:"PORT" default:"8080" json:"PORT"`
    DBHost         string `env:"DB_HOST" required:"true" json:"DB_HOST"`
    HttpTimeout    int    `env:"DEFAULT_HTTP_TIMEOUT" default:"30" json:"DEFAULT_HTTP_TIMEOUT"`
}

var Envs Config

func init() {
    if err := envconfig.Process("", &Envs); err != nil {
        log.Fatalf("config error: %v", err)
    }
}
```

## Swagger godoc comments

```go
// GetOrder godoc
// @Summary      Get order by ID
// @Description  Returns a single order
// @Produce      json
// @Tags         orders
// @Param        id   path      string  true  "Order ID"
// @Success      200  {object}  OrderResponse
// @Failure      404  {object}  ErrorResponse
// @Router       /orders/{id} [get]
func GetOrder(ctx *gin.Context) { ... }
```

## Docker Multi-Stage Build

```dockerfile
FROM base    # Install tools
FROM ci      # Run tests, generate swagger
FROM builder # go build with CGO_ENABLED=0
FROM scratch # Final image — binary only
```
