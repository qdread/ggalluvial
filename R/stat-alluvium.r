#' Alluvial positions
#' 
#' Given a dataset with alluvial structure, \code{stat_alluvium} calculates the 
#' centroids (\code{x} and \code{y}) of the \strong{lodes}, the intersections of
#' the alluvia with the strata, together with their weights (heights; 
#' \code{ymin} and \code{ymax}). It leverages the \code{group} aesthetic for 
#' plotting purposes (for now).
#' 
#' @section Aesthetics: \code{stat_alluvium} understands the following
#'   aesthetics (required aesthetics are in bold):
#' \itemize{
#'   \item \code{x}
#'   \item \code{stratum}
#'   \item \code{alluvium}
#'   \item \code{axis[0-9]*} (\code{axis1}, \code{axis2}, etc.)
#'   \item \code{weight}
#'   \item \code{group}
#' }
#' Currently, \code{group} is ignored.
#' Use \code{x}, \code{stratum}, and \code{alluvium} for data in lode form and 
#' \code{axis[0-9]*} for data in alluvium form (see \code{\link{is_alluvial}});
#' arguments to parameters inconsistent with the data format will be ignored.
#' 
#' @name stat-alluvium
#' @import ggplot2
#' @seealso \code{\link{geom_alluvium}} for the corresponding geom,
#'   \code{\link{stat_stratum}} and \code{\link{geom_stratum}} for
#'   intra-axis boxes, 
#'   \code{\link{alluvium_ts}} for a time series implementation, and 
#'   \code{\link{ggalluvial}} for a shortcut method.
#' @inheritParams layer
#' @param lode.guidance The function to prioritize the axis variables for 
#'   ordering the lodes within each stratum. Defaults to "zigzag", other options
#'   include "rightleft", "leftright", "rightward", and "leftward" (see 
#'   \code{\link{lode-guidance-functions}}).
#' @param aes.bind Whether to prioritize aesthetics before axes (other than the
#'   index axis) when ordering the lodes within each stratum. Defaults to FALSE.
#' @param lode.ordering A list (of length the number of axes) of integer vectors
#'   (each of length the number of rows of \code{data}) or NULL entries 
#'   (indicating no imposed ordering), or else a numeric matrix of corresponding
#'   dimensions, giving the preferred ordering of alluvia at each axis. This 
#'   will be used to order the lodes within each stratum by sorting the lodes 
#'   first by stratum and then by the provided vectors.
#' @example inst/examples/ex-alluvium.r
#' @usage NULL
#' @export
stat_alluvium <- function(mapping = NULL,
                          data = NULL,
                          geom = "alluvium",
                          na.rm = FALSE,
                          show.legend = NA,
                          inherit.aes = TRUE,
                          ...) {
  layer(
    stat = StatAlluvium,
    data = data,
    mapping = mapping,
    geom = geom,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(
      na.rm = na.rm,
      ...
    )
  )
}

#' @rdname stat-alluvium
#' @usage NULL
#' @export
StatAlluvium <- ggproto(
  "StatAlluvium", Stat,
  
  setup_params = function(data, params) {
    
    if (!is.null(params$lode.ordering)) {
      if (is.list(params$lode.ordering)) {
        # replace any null entries with uniform NA vectors
        wh.null <- which(sapply(params$lode.ordering, is.null))
        for (w in wh.null) params$lode.ordering[[w]] <- rep(NA, nrow(data))
        # convert list to array (requires equal-length numeric entries)
        params$lode.ordering <- do.call(cbind, params$lode.ordering)
      }
      # check that array has correct dimensions
      stopifnot(dim(params$lode.ordering) ==
                  c(nrow(data), length(get_axes(names(data)))))
    }
    
    params
  },
  
  setup_data = function(data, params) {
    
    # assign uniform weight if not provided
    if (is.null(data$weight)) {
      data$weight <- rep(1, nrow(data))
    }
    
    type <- get_alluvial_type(data)
    if (type == "none") {
      stop("Data is not in a recognized alluvial form ",
           "(see `?is_alluvial` for details).")
    }
    
    if (params$na.rm) {
      data <- na.omit(data = data)
    } else {
      data <- na_keep(data = data, type = type)
    }
    
    # ensure that data is in lode form
    if (type == "alluvia") {
      axis_ind <- get_axes(names(data))
      data <- to_lodes(data = data,
                       key = "x", value = "stratum", id = "alluvium",
                       axes = axis_ind)
      # positioning requires numeric 'x'
      data$x <- as.numeric(as.factor(data$x))
    }
    
    data
  },
  
  compute_panel = function(data, scales, params,
                           lode.guidance = "zigzag",
                           aes.bind = FALSE,
                           lode.ordering = NULL) {
    
    # introduce any empty lodes in non-empty alluvia
    data <- merge(data, expand.grid(list(
      x = sort(unique(data$x)),
      alluvium = sort(unique(data$alluvium))
    )), all = TRUE)
    # sort data by 'x' then 'alluvium' (to match 'alluv')
    data <- data[do.call(order, data[, c("x", "alluvium")]), ]
    
    if (is.null(lode.ordering)) lode_fn <- get(paste0("lode_", lode.guidance))
    
    # alluvial fields
    alluv_col <- c("x", "stratum", "alluvium")
    # aesthetic fields
    aes_col <- setdiff(names(data), c(alluv_col, "weight", "PANEL", "group"))
    # put axis fields into alluvial form
    alluv <- to_alluvia(data[, alluv_col],
                        key = "x", value = "stratum", id = "alluvium")
    stopifnot(nrow(alluv) == nrow(data) / dplyr::n_distinct(data$x))
    # sort by 'alluvium' (to match 'data')
    alluv <- alluv[order(alluv$alluvium), ]
    # axis and aesthetic indices
    axis_ind <- which(!(names(alluv) %in% names(data)))
    
    # vertical positions of flows at each axis
    position_lodes <- function(i) {
      # depends on whether the user has provided a lode.ordering
      if (is.null(lode.ordering)) {
        # order axis indices
        axis_seq <- axis_ind[lode_fn(n = length(axis_ind), i = i)]
        # order lodes according to axes and aesthetics
        lode_seq <- do.call(
          order,
          if (aes.bind) {
            c(alluv[axis_seq[1]],
              subset(data, x == names(alluv)[axis_ind[i]])[aes_col],
              alluv[axis_seq[-1]])
          } else {
            alluv[axis_seq]
          }
        )
      } else {
        lode_seq <- order(alluv[[axis_ind[i]]], lode.ordering[, i])
      }
      # lode floors and ceilings along axis
      subdata <- subset(data, x == names(alluv)[axis_ind[i]])
      cumweight <- cumsum(subdata$weight[lode_seq])
      ymin_seq <- c(0, cumweight)
      ymax_seq <- c(cumweight, sum(subdata$weight))
      # lode breaks
      data.frame(x = names(alluv)[axis_ind[i]],
                 ymin = ymin_seq[order(lode_seq)],
                 ymax = ymax_seq[order(lode_seq)])
    }
    lode_positions <- do.call(rbind, lapply(1:length(axis_ind), position_lodes))
    stopifnot(all(data$x == lode_positions$x))
    data <- cbind(data, lode_positions[, -1])
    
    # add vertical centroids and 'group' to encode alluvia
    data <- transform(data,
                      y = (ymin + ymax) / 2,
                      group = alluvium)
    
    data
  }
)