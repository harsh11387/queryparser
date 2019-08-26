# Copyright 2019 Cloudera Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

translate_nin <- function(expr) {
  if (length(expr) == 1) {
    return(expr)
  } else {
    if (expr[[1]] == quote(`%nin%`)) {
      expr[[1]] <- quote(`%in%`)
      return(as.call(lapply(
        str2lang(paste0("!(", deparse(expr),")")),
        translate_nin
      )))
    } else {
      return(as.call(lapply(expr, translate_nin)))
    }
  }
}

translate_distinct_functions <- function(expr, tidyverse) {
  if (tidyverse) {
    sql_aggregate_functions <- setdiff(sql_aggregate_functions, "count")
  }
  for (func in sql_aggregate_functions) {
    expr <- translate_distinct_function(expr, func, tidyverse)
  }
  expr
}

translate_distinct_function <- function(expr, func, tidyverse) {
  if (length(expr) == 1) {
    return(expr)
  } else {
    if (expr[[1]] == str2lang(paste0(func, "_distinct"))) {
      if (!tidyverse && length(expr) > 2) {
        stop(
          "Multiple expressions after DISTINCT in an aggregate",
          "function is not supported when tidyverse = FALSE",
          call. = FALSE
        )
      }
      return(as.call(lapply(
        str2lang(paste0(gsub(
          paste0("^", func, "_distinct\\("),
          paste0(func, "(unique("),
          deparse(expr),
          ignore.case = TRUE
        ),
        ")")), translate_distinct_function, func, tidyverse
      )))
    } else {
      return(as.call(lapply(expr, translate_distinct_function, func, tidyverse)))
    }
  }
}

translate_direct <- function(expr, tidyverse) {
  if (tidyverse) {
    envir <- translation_environment_direct_tidyverse
  } else {
    envir <- translation_environment_direct_base
  }
  do.call(substitute, list(expr, envir))
}

translate_indirect <- function(expr, tidyverse) {
  if (tidyverse) {
    envir <- translation_environment_indirect_tidyverse
  } else {
    envir <- translation_environment_indirect_base
  }
  partial_eval(expr, envir)
}