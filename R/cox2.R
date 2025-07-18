#' @title cox2.display: table for coxph.object with model option: TRUE - allow "frailty" or "cluster" model
#' @description Table for coxph.object with model option: TRUE - allow "frailty" or "cluster" model
#' @param cox.obj.withmodel coxph.object with model option: TRUE
#' @param dec Decimal point, Default: 2
#' @param msm Multi state model, Default: NULL
#' @param pcut.univariate pcut.univariate, Default: NULL
#' @return Table, cluster/frailty info, metrics, caption
#' @details GEE like - cluster, Mixed effect model like - frailty
#' @examples
#' library(survival)
#' data(lung)
#' fit1 <- coxph(Surv(time, status) ~ ph.ecog + age + cluster(inst), data = lung, model = TRUE)
#' fit2 <- coxph(Surv(time, status) ~ ph.ecog + age + frailty(inst), data = lung, model = TRUE)
#' cox2.display(fit1)
#' cox2.display(fit2)
#' @rdname cox2.display
#' @export
#' @importFrom survival coxph cluster frailty
#' @importFrom stats formula update AIC
#'
cox2.display <- function(cox.obj.withmodel, dec = 2, msm = NULL, pcut.univariate = NULL, data_for_univariate = NULL) {
  model <- cox.obj.withmodel
  if (!any(class(model) == "coxph")) {
    stop("Model not from Cox model")
  }
  xf <- attr(model$terms, "term.labels") # Independent vars
  xf_keep <- xf
  xf.old <- xf
  xc <- NULL
  xc.vn <- NULL
  x.weight <- model$call$weight
  mtype <- "normal"
  x.id <- model$call$id
  
  
  if (length(grep("strata", xf)) > 0) {
    xf <- xf[-grep("strata", xf)]
  } else if (length(grep("frailty\\(", xf)) > 0) {
    xf <- xf[-grep("frailty\\(", xf)]
    mtype <- "frailty"
    xc <- setdiff(xf.old, xf)
    xc.vn <- strsplit(strsplit(xc, "frailty\\(")[[1]][2], "\\)")[[1]][1]
  } else if (!(is.null(model$call$cluster))) {
    mtype <- "cluster"
    # xfull <-  strsplit(as.character(model$call[[2]][3]), " \\+ ")[[1]]
    # xc <- setdiff(xfull, xf)
    # xf <- ifelse(length(grep("cluster\\(",xf)) > 0, xf[-grep("cluster\\(",xf)], xf)
    # xc <- setdiff(xf.old, xf)
    xc <- as.character(model$call$cluster)
    xc.vn <- xc
    # xc.vn <- strsplit(strsplit(xc, "cluster\\(")[[1]][2], "\\)")[[1]][1]
  }
  
  # handle no event case
  if (model$nevent == 0) {
    # metrics
    no.obs <- model$n
    no.event <- model$nevent
    aic <- NA # no event
    c_index <- "NA (NA)" # no event
    
    # vars
    var_names <- xf  # variable names
    if (length(var_names) == 0) var_names <- "No variables"
    if (length(var_names) == 1) {
      col_names <- c("HR(95%CI)", "P value")
    } else {
      col_names <- c("crude HR(95%CI)", "crude P value", "adj. HR(95%CI)", "adj. P value")
    }
    fix.all.unlist <- matrix(NA, nrow = length(var_names), ncol = length(col_names), 
                             dimnames = list(var_names, col_names))
    
    # metric table
    metric.mat <- cbind(c(NA, no.obs, no.event, aic, c_index), matrix(NA, 5, max(1, ncol(fix.all.unlist) - 1)))
    rownames(metric.mat) <- c(NA, "No. of observations", "No. of events", "AIC", "C-Index")
    
    # caption
    surv.string <- as.character(attr(model$terms, "variables")[[2]])
    time.var.name <- paste(sapply(2:(length(surv.string) - 1), function(i) paste(surv.string[i])), collapse = ", ")
    status.var.name <- surv.string[length(surv.string)]
    intro <- paste("Cox model on time ('", time.var.name, "') to event ('", status.var.name, "')", sep = "")
    
    # type info
    cvname_for_caption <- if (is.null(xc.vn)) "N/A" else xc.vn
    if (mtype == "cluster") {
      intro <- paste("Marginal", intro, "- Group", cvname_for_caption)
    } else if (mtype == "frailty") {
      intro <- paste("Frailty", intro, "- Group", cvname_for_caption)
    }
    
    # fixed effect
    var_names <- xf
    if (length(var_names) == 0) var_names <- "No variables"
    if (length(var_names) == 1) {
      col_names <- c("HR(95%CI)", "P value")
    } else {
      col_names <- c("crude HR(95%CI)", "crude P value", "adj. HR(95%CI)", "adj. P value")
    }
    fix.all.unlist <- matrix(NA, nrow = length(var_names), ncol = length(col_names), 
                             dimnames = list(var_names, col_names))
    
    # random effect
    ranef.mat <- NULL
    if (mtype == "cluster" || mtype == "frailty") {
      ranef.mat <- cbind(c(NA, NA), matrix(NA, 2, max(1, ncol(fix.all.unlist) - 1)))
      if (mtype == "cluster") {
        rownames(ranef.mat) <- c("cluster", xc.vn)
      } else { # frailty
        rownames(ranef.mat) <- c("frailty", xc.vn)
      }
    }
    
    # return
    if (is.null(ranef.mat)) {
      return(list(table = fix.all.unlist, metric = metric.mat, caption = intro))
    } else {
      return(list(table = fix.all.unlist, ranef = ranef.mat, metric = metric.mat, caption = intro))
    }
  }
  
  formula.surv <- as.character(model$formula)[2]
  formula.ranef <- paste(" + ", xc, sep = "")
  mdata <- model$model
  if (length(xc) == 0) {
    formula.ranef <- NULL
  } else {
    names(mdata)[names(mdata) == xc] <- xc.vn
  }
  #categorical_vars <- attr(terms(model), "term.labels")[sapply(mdata[attr(terms(model), "term.labels")], is.factor)]
  categorical_vars <- xf[sapply(mdata[xf], is.factor)]
  
  # if (is.null(data)){
  #  mdata = data.frame(get(as.character(model$call)[3]))
  # } else{
  #  mdata = data.frame(data)
  # }
  
  if (length(xf) == 1) {
    uni.res <- data.frame(summary(model)$coefficients)
    # uni.res <- data.frame(summary(coxph(as.formula(paste("mdata[, 1]", "~", xf, formula.ranef, sep="")), data = mdata))$coefficients)
    rn.uni <- lapply(list(uni.res), rownames)
    names(uni.res)[ncol(uni.res)] <- "p"
    uni.res2 <- NULL
    if (mtype == "normal") {
      uni.res2 <- uni.res[, c(1, 3, 4, 5)]
      if (length(grep("robust.se", names(uni.res))) > 0) {
        uni.res2 <- uni.res[, c(1, 4, 5, 6)]
      }
    } else if (mtype == "cluster") {
      uni.res2 <- uni.res[, c(1, 4, 5, 6)]
    } else {
      uni.res2 <- uni.res[-nrow(uni.res), c(1, 3, 4, 6)]
    }
    fix.all <- coxExp(uni.res2, dec = dec)
    colnames(fix.all) <- c("HR(95%CI)", "P value")
    
    if (mtype == "frailty") {
      # rownames(fix.all) <- c(names(model$coefficients), "frailty")
      rownames(fix.all) <- names(model$coefficients)
    } else {
      rownames(fix.all) <- names(model$coefficients)
    }
  } else {
    countings <- length(unlist(attr(mdata[[1]], "dimnames")[2]))
    mdata2 <- cbind(matrix(sapply(mdata[, 1], `[[`, 1), ncol = countings), mdata[, -1])
    names(mdata2)[1:countings] <- as.character(model$formula[[2]][2:(countings + 1)])
    
    if (!is.null(x.weight)) {
      names(mdata2)[names(mdata2) == "(weights)"] <- as.character(x.weight)
    }
    if (!is.null(xc.vn)) {
      names(mdata2)[ncol(mdata2)] <- xc.vn
    }
    if (!is.null(x.id)){
      names(mdata2)[names(mdata2)== "(id)"] <- as.character(x.id)
    }
    
    if (!is.null(msm)) {
      if (is.null(data_for_univariate)) {
        baseformula <- stats::formula(paste(c(". ~ .", xf), collapse = " - "))
        unis <- lapply(xf, function(x) {
          newfit <- update(model, stats::formula(paste(c(baseformula, x), collapse = "+")))
          uni.res <- data.frame(summary(newfit)$coefficients)
          if (grepl(":", x)) {
            uni.res <- uni.res[rownames(uni.res) %in% rownames(summary(model)$coefficients), ]
          } else {
            uni.res <- uni.res[grep(x, rownames(uni.res)), ]
          }
          # uni.res <- uni.res[c(2:nrow(uni.res), 1), ]
          # uni.res <- data.frame(summary(coxph(as.formula(paste("mdata[, 1]", "~", x, formula.ranef, sep="")), data = mdata))$coefficients)
          names(uni.res)[ncol(uni.res)] <- "p"
          uni.res2 <- NULL
          if (mtype == "normal") {
            uni.res2 <- uni.res[, c(1, 3, 4, 5)]
            if (length(grep("robust.se", names(uni.res))) > 0) {
              uni.res2 <- uni.res[, c(1, 4, 5, 6)]
            }
          } else if (mtype == "cluster") {
            uni.res2 <- uni.res[, c(1, 4, 5, 6)]
          } else {
            uni.res2 <- uni.res[, c(1, 3, 4, 6)]
          }
          return(uni.res2)
        })
        keep <- !vapply(unis, is.null, logical(1))
        unis        <- unis[keep]
        xf_keep     <- xf[keep]
        if (length(unis) == 0) stop("All univariate fits failed")
        rn.uni <- lapply(unis, rownames)
        unis2 <- Reduce(rbind, unis)
        uni.res <- unis2
        colnames(uni.res) <- c("coef","se","z","p")
        } else {unis <- lapply(xf, function(x) {
          lhs      <- paste(deparse(model$call$formula[[2]]), collapse = "")
          randTerm <- if (mtype=="cluster") {
            paste0("+cluster(", xc.vn, ")")
          } else if (mtype=="frailty") {
            paste0("+frailty(", xc.vn, ")")
          } else ""
          uni_fmla <- as.formula(paste0(lhs, " ~ ", x, randTerm))

          needed   <- all.vars(model$call$formula[[2]])
          if (randTerm!="") needed <- c(needed, xc.vn)
          df_uni   <- data_for_univariate[complete.cases(data_for_univariate[, c(needed, x)]), ]
          
          fit_uni  <- survival::coxph(uni_fmla,
                                      data      = df_uni,
                                      model     = TRUE,
                                      na.action = na.omit)
          
          cm       <- summary(fit_uni)$coefficients
          cols     <- c(1,
                        which(colnames(cm) %in% c("se(coef)","robust.se")),
                        which(colnames(cm)=="z"),
                        which(colnames(cm) %in% c("Pr(>|z|)","Pr(>|t|)")))[1:4]
          return(cm[, cols, drop=FALSE])
        })
        keep <- !vapply(unis, is.null, logical(1))
        unis        <- unis[keep]
        xf_keep     <- xf[keep]
        if (length(unis) == 0) stop("All univariate fits failed")
        rn.uni <- lapply(unis, rownames)
        unis2 <- Reduce(rbind, unis)
        uni.res <- unis2
        colnames(uni.res) <- c("coef","se","z","p")
        
      }
      
      if (is.null(pcut.univariate)){
        mul.res <- data.frame(coefNA(model))
      }else{
        significant_vars <- rownames(uni.res)[as.numeric(uni.res[, 4]) < pcut.univariate]
        
        if (length(categorical_vars) != 0){
          factor_vars_list <- lapply(categorical_vars, function(factor_var) {
            factor_var_escaped <- gsub("\\(", "\\\\(", factor_var)  # "(" → "\\("
            factor_var_escaped <- gsub("\\)", "\\\\)", factor_var_escaped)  # ")" → "\\)"
            
            
            matches <- grep(paste0("^", factor_var_escaped), rownames(coefNA(model)), value = TRUE)
            return(matches)
          })
          names(factor_vars_list) <- categorical_vars
          
          for (key in names(factor_vars_list)) {
            variables <- factor_vars_list[[key]]
            
            p_values <- uni.res[variables, 4]
            
            if (any(p_values < pcut.univariate, na.rm = TRUE)) {
              significant_vars <- setdiff(significant_vars, variables)
              
              significant_vars <- unique(c(significant_vars, key))
            }
          }
        }
        
        if (length(significant_vars) == 0 ){
          mul.res <- matrix(NA, nrow = nrow(uni.res), ncol = ncol(data.frame(coefNA(model))))
          rownames(mul.res) <- rownames(uni.res)
          #colnames(mul.res) <- c("coef","exp.coef.","se.coef.","robust.se" ,"z", "Pr...z..")
          colnames(mul.res) <- colnames(data.frame(coefNA(model)))
        }else{
          if(mtype=="normal"){
            selected_formula <- as.formula(paste(formula.surv, "~", paste(significant_vars, collapse = " + ")))
          }else{
            selected_formula <- as.formula(paste(formula.surv, "~", paste(significant_vars, collapse = " + "),"+",paste0(mtype, '(',xc.vn,')')))
          }
          selected_model <- coxph(selected_formula, data = mdata2, model = TRUE) 
          mul <- coefNA(selected_model)
          mul.res <- matrix(NA, nrow = nrow(uni.res), ncol = ncol(data.frame(coefNA(model))))
          rownames(mul.res) <- rownames(uni.res)
          #colnames(mul.res) <- c("coef","exp.coef.","se.coef.","robust.se" ,"z", "Pr...z..")
          colnames(mul.res) <- colnames(data.frame(coefNA(model)))
          if (!is.null(mul)) {
            mul_no_intercept <- mul[!grepl("Intercept", rownames(mul)), , drop = FALSE]
            
            
            for (var in rownames(mul_no_intercept)) { 
              mul.res[var, ] <- mul_no_intercept[var,]
            }
          }
        }
        
      }
      
      
      uni.res <- uni.res[rownames(uni.res) %in% rownames(mul.res), ]
      colnames(mul.res)[ncol(mul.res)] <- "p"
      mul_for_exp <- mul.res[rownames(uni.res), c(1, 2, ncol(mul.res)), drop = FALSE]
      colnames(mul_for_exp)[3] <- "p"  # 세 번째 열이 p가 되게 만듭니다
      fix.all <- cbind(
        coxExp(uni.res,    dec = dec),
        coxExp(mul_for_exp, dec = dec)
      )      
      colnames(fix.all) <- c("crude HR(95%CI)", "crude P value", "adj. HR(95%CI)", "adj. P value")
      rownames(fix.all) <- rownames(uni.res)
    } else {
      if (is.null(data_for_univariate)) {
        basemodel <- update(model, stats::formula(paste(c(". ~ .", xf), collapse = " - ")), data = mdata2)
        
        unis <- lapply(xf, function(x) {
          newfit <- update(basemodel, stats::formula(paste0(". ~ . +", x)), data = mdata2)
          uni.res <- data.frame(summary(newfit)$coefficients)
          if (grepl(":", x)) {
            uni.res <- uni.res[rownames(uni.res) %in% rownames(summary(model)$coefficients), ]
          } else {
            uni.res <- uni.res[grep(x, rownames(uni.res)), ]
          }
          # uni.res <- uni.res[c(2:nrow(uni.res), 1), ]
          # uni.res <- data.frame(summary(coxph(as.formula(paste("mdata[, 1]", "~", x, formula.ranef, sep="")), data = mdata))$coefficients)
          names(uni.res)[ncol(uni.res)] <- "p"
          # if ("robust.se" %in% names(uni.res)) {
          #   uni.res$robust.se <- NULL
          # }
          
          uni.res2 <- NULL
          if (mtype == "normal") {
            uni.res2 <- uni.res[, c(1, 3, 4, 5)]
            if (length(grep("robust.se", names(uni.res))) > 0) {
              uni.res2 <- uni.res[, c(1, 4, 5, 6)]
            }
          } else if (mtype == "cluster") {
            uni.res2 <- uni.res[, c(1, 4, 5, 6)]
          } else {
            uni.res2 <- uni.res[, c(1, 3, 4, 6)]
          }
          return(uni.res2)
        })
        keep <- !vapply(unis, is.null, logical(1))
        unis        <- unis[keep]
        xf_keep     <- xf[keep]
        if (length(unis) == 0) stop("All univariate fits failed")
        rn.uni <- lapply(unis, rownames)
        unis2 <- Reduce(rbind, unis)
        uni.res <- unis2
        colnames(uni.res) <- c("coef","se","z","p")
      } else {
        unis <- lapply(xf, function(x) {
        lhs      <- paste(deparse(model$call$formula[[2]]), collapse = "")
        randTerm <- if (mtype=="cluster") {
          paste0("+cluster(", xc.vn, ")")
        } else if (mtype=="frailty") {
          paste0("+frailty(", xc.vn, ")")
        } else ""
        uni_fmla <- as.formula(paste0(lhs, " ~ ", x, randTerm))
        
        needed   <- all.vars(model$call$formula[[2]])
        if (randTerm!="") needed <- c(needed, xc.vn)
        df_uni   <- data_for_univariate[complete.cases(data_for_univariate[, c(needed, x)]), ]
        
        fit_uni  <- survival::coxph(uni_fmla,
                                    data      = df_uni,
                                    model     = TRUE,
                                    na.action = na.omit)
        
        cm       <- summary(fit_uni)$coefficients
        cols     <- c(1,
                      which(colnames(cm) %in% c("se(coef)","robust.se")),
                      which(colnames(cm)=="z"),
                      which(colnames(cm) %in% c("Pr(>|z|)","Pr(>|t|)")))[1:4]
        return(cm[, cols, drop=FALSE])
      })
      keep <- !vapply(unis, is.null, logical(1))
      unis        <- unis[keep]
      xf_keep     <- xf[keep]
      if (length(unis) == 0) stop("All univariate fits failed")
      rn.uni <- lapply(unis, rownames)
      unis2 <- Reduce(rbind, unis)
      uni.res <- unis2
      colnames(uni.res) <- c("coef","se","z","p")
      }
      
      
      if(is.null(pcut.univariate)){
        mul.res <- data.frame(coefNA(model))
      }else{
        
        significant_vars <- rownames(uni.res)[as.numeric(uni.res[, 4]) < pcut.univariate]
        
        if (length(categorical_vars) != 0){
          factor_vars_list <- lapply(categorical_vars, function(factor_var) {
            factor_var_escaped <- gsub("\\(", "\\\\(", factor_var)  # "(" → "\\("
            factor_var_escaped <- gsub("\\)", "\\\\)", factor_var_escaped)  # ")" → "\\)"
            
            
            matches <- grep(paste0("^", factor_var_escaped), rownames(coefNA(model)), value = TRUE)
            return(matches)
          })
          names(factor_vars_list) <- categorical_vars
          
          for (key in names(factor_vars_list)) {
            variables <- factor_vars_list[[key]]
            
            p_values <- uni.res[variables, 4]
            
            if (any(p_values < pcut.univariate, na.rm = TRUE)) {
              significant_vars <- setdiff(significant_vars, variables)
              
              significant_vars <- unique(c(significant_vars, key))
            }
          }
        }
        
        if (length(significant_vars) == 0 ){
          mul.res <- matrix(NA, nrow = nrow(uni.res), ncol = ncol(data.frame(coefNA(model))))
          rownames(mul.res) <- rownames(uni.res)
          #colnames(mul.res) <- c("coef","exp.coef.","se.coef.","robust.se" ,"z", "Pr...z..")
          colnames(mul.res) <- colnames(data.frame(coefNA(model)))
        }else{
          if(mtype=="normal"){
            selected_formula <- as.formula(paste(formula.surv, "~", paste(significant_vars, collapse = " + ")))
          }else{
            selected_formula <- as.formula(paste(formula.surv, "~", paste(significant_vars, collapse = " + "),"+",paste0(mtype, '(',xc.vn,')')))
          }
          selected_model <- coxph(selected_formula, data = mdata2, model = TRUE) 
          mul <- coefNA(selected_model)
          mul.res <- matrix(NA, nrow = nrow(uni.res), ncol = ncol(data.frame(coefNA(model))))
          rownames(mul.res) <- rownames(uni.res)
          #colnames(mul.res) <- c("coef","se(coef)","se2","Chisq","DF","p" )
          colnames(mul.res) <- colnames(data.frame(coefNA(model)))
          if (!is.null(mul)) {
            mul_no_intercept <- mul[!grepl("Intercept", rownames(mul)), , drop = FALSE]
            
            
            for (var in rownames(mul_no_intercept)) { 
              mul.res[var, ] <- mul_no_intercept[var,]
            }
          }
          
        }
        
      }
      
      uni.res <- uni.res[rownames(uni.res) %in% rownames(mul.res), ]
      colnames(mul.res)[ncol(mul.res)] <- "p"
      mul_for_exp <- mul.res[rownames(uni.res), c(1, 2, ncol(mul.res)), drop = FALSE]
      colnames(mul_for_exp)[3] <- "p"  # 세 번째 열이 p가 되게 만듭니다
      fix.all <- cbind(
        coxExp(uni.res,    dec = dec),
        coxExp(mul_for_exp, dec = dec)
      )
      colnames(fix.all) <- c("crude HR(95%CI)", "crude P value", "adj. HR(95%CI)", "adj. P value")
      rownames(fix.all) <- rownames(uni.res)
    }
  }
  ## rownames
  fix.all.list <- lapply(seq_along(xf_keep), function(x) {
    fix.all[rownames(fix.all) %in% rn.uni[[x]], ]
  })
  varnum.mfac <- which(lapply(fix.all.list, length) > ncol(fix.all))
  lapply(varnum.mfac, function(x) {
    fix.all.list[[x]] <<- rbind(rep(NA, ncol(fix.all)), fix.all.list[[x]])
  })
  fix.all.unlist <- Reduce(rbind, fix.all.list)
  
  rn.list <- lapply(seq_along(xf_keep), function(x) {
    rownames(fix.all)[rownames(fix.all) %in% rn.uni[[x]]]
  })
  varnum.2fac <- which(lapply(xf, function(x) {
    length(sapply(mdata, levels)[[x]])
  }) == 2)
  lapply(varnum.2fac, function(x) {
    rn.list[[x]] <<- paste(xf[x], ": ", levels(mdata[, xf[x]])[2], " vs ", levels(mdata[, xf[x]])[1], sep = "")
  })
  lapply(varnum.mfac, function(x) {
    if (grepl(":", xf[x])) {
      a <- unlist(strsplit(xf[x], ":"))[1]
      b <- unlist(strsplit(xf[x], ":"))[2]
      
      if (a %in% xf && b %in% xf) {
        ref <- paste0(a, levels(mdata[, a])[1], ":", b, levels(mdata[, b])[1])
        rn.list[[x]] <<- c(paste(xf[x], ": ref.=", ref, sep = ""), gsub(xf[x], "   ", rn.list[[x]]))
      } else {
        rn.list[[x]] <<- c(paste(xf[x], ": ref.=NA", model$xlevels[[xf[x]]][1], sep = ""), gsub(xf[x], "   ", rn.list[[x]]))
      }
    } else {
      rn.list[[x]] <<- c(paste(xf[x], ": ref.=", levels(mdata[, xf[x]])[1], sep = ""), gsub(xf[x], "   ", rn.list[[x]]))
    }
  })
  if (class(fix.all.unlist)[1] == "character") {
    fix.all.unlist <- t(data.frame(fix.all.unlist))
  }
  if (is.null(msm)) {
    rownames(fix.all.unlist) <- unlist(rn.list)
  }
  
  pv.colnum <- which(colnames(fix.all.unlist) %in% c("P value", "crude P value", "adj. P value"))
  for (i in pv.colnum) {
    fix.all.unlist[, i] <- ifelse(as.numeric(fix.all.unlist[, i]) < 0.001, "< 0.001", round(as.numeric(fix.all.unlist[, i]), dec + 1))
  }
  
  
  ## random effect
  # ranef = unlist(model$vcoef)
  # ranef.out = round(ranef, dec)
  ranef.mat <- NULL
  if (mtype == "cluster") {
    ranef.mat <- cbind(c(NA, NA), matrix(NA, length(xc) + 1, ncol(fix.all) - 1))
    # clname = strsplit(xc, "\\(")[[1]]
    clname <- c("cluster", xc)
    cvname <- strsplit(paste(clname[-1], collapse = "("), "\\)")[[1]]
    cvname <- paste(cvname[length(cvname)], collapse = ")")
    rownames(ranef.mat) <- c(clname[1], cvname)
  } else if (mtype == "frailty") {
    ranef.mat <- cbind(c(NA, NA), matrix(NA, length(xc) + 1, ncol(fix.all) - 1))
    clname <- strsplit(xc, "\\(")[[1]]
    cvname <- strsplit(paste(clname[-1], collapse = "("), "\\)")[[1]]
    cvname <- paste(cvname[length(cvname)], collapse = ")")
    rownames(ranef.mat) <- c(clname[1], cvname)
  }
  
  
  ## metric
  # no.grp = unlist(lapply(model$frail, length))
  no.obs <- model$n
  no.event <- model$nevent
  aic <- stats::AIC(model)
  ccd <- model$concordance
  concordance_value <- round(ccd["concordance"], 3)
  std_value <- round(ccd["std"], 3)
  c_index <- paste0(concordance_value, "(", std_value, ")")
  metric.mat <- cbind(c(NA, no.obs, no.event, aic, c_index), matrix(NA, 5, ncol(fix.all) - 1))
  rownames(metric.mat) <- c(NA, "No. of observations", "No. of events", "AIC", "C-Index")
  
  ## Integrated ll
  # ll = model$loglik[2]
  # aic = -2 * ll -2*model$df[1]
  
  ## caption
  surv.string <- as.character(attr(model$terms, "variables")[[2]])
  time.var.name <- paste(sapply(2:(length(surv.string) - 1), function(i) paste(surv.string[i])), collapse = ", ")
  status.var.name <- surv.string[length(surv.string)]
  intro <- paste("Cox model on time ('", time.var.name, "') to event ('", status.var.name, "')", sep = "")
  if (mtype == "cluster") {
    intro <- paste("Marginal", intro, "- Group", cvname)
  } else if (mtype == "frailty") {
    intro <- paste("Frailty", intro, "- Group", cvname)
  }
  if (!is.null(msm)) {
    states <- paste(sapply(seq_along(model$states), function(i) paste(i, model$states[i], sep = ": ")), collapse = ", ")
    intro[2] <- paste("states", states)
  }
  states <- model$states
  
  var.names0 <- attr(model$terms, "term.labels")
  if (length(grep("strata", var.names0)) > 0) {
    intro <- paste(intro, " with '", var.names0[grep("strata", var.names0)], "'", sep = "")
  }
  
  if (is.null(ranef.mat)) {
    return(list(table = fix.all.unlist, metric = metric.mat, caption = intro))
  } else {
    return(list(table = fix.all.unlist, ranef = ranef.mat, metric = metric.mat, caption = intro))
  }
}