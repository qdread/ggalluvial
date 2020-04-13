# convert rectangle to polygon
# (lifted from [ggplot2::geom_rect()])
rect_to_poly <- function(xmin, xmax, ymin, ymax) {
  data.frame(
    y = c(ymax, ymax, ymin, ymin, ymax),
    x = c(xmin, xmax, xmax, xmin, xmin)
  )
}

# alternative curve options
# each is a function that takes [0,1] to [0,1]
# degree-3 polynomial with degree-1 critical endpoints
unit_cubic <- function(x) 3*x^2 - 2*x^3
# degree-5 polynomial with degree-2 critical endpoints
unit_quintic <- function(x) 10*x^3 - 15*x^4 + 6*x^5
# sinusoidal function with crests at endpoints
unit_sine <- function(x) {
  t <- (x - .5) * pi
  sin(t) / 2 + .5
}
# inverse tangent function compressed from a specified symmetric domain
unit_arctangent <- function(x, reach) {
  if (is.null(reach)) reach <- 2 + sqrt(3)
  t <- (x - .5) * 2 * reach
  atan(t) / 2 / atan(reach) + .5
}
# sigmoid function compressed from a specified symmetric domain
unit_sigmoid <- function(x, reach) {
  if (is.null(reach)) reach <- 6
  t <- (x - .5) * 2 * reach
  (stats::plogis(t) - stats::plogis(-reach)) /
    diff(stats::plogis(c(-1, 1) * reach))
}

# return the desired flow curve function
make_curve_fun <- function(curve, reach) {
  curve <- match.arg(
    curve,
    c("linear", "cubic", "quintic", "sine", "arctangent", "sigmoid")
  )
  switch(
    curve,
    # polynomial curves
    linear = identity,
    cubic = unit_cubic,
    quintic = unit_quintic,
    # sinusoidal curve
    sine = unit_sine,
    # asymptotic curves (with specifiable reach)
    arctangent = function(x) unit_arctangent(x, reach),
    sigmoid = function(x) unit_sigmoid(x, reach)
  )
}
