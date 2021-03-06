#' KS, ROC, Lift, PR
#'
#' \code{perf_plot} provides performance evaluations, such as kolmogorov-smirnow(ks), ROC, lift and precision-recall curves, based on provided label and predicted probability values.
#'
#' @name perf_plot
#' @param label Label values, such as 0s and 1s, 0 represent for good and 1 for bad.
#' @param pred Predicted probability values.
#' @param title Title of plot, default "train".
#' @param groupnum The group numbers when calculating bad probability, default 20.
#' @param type Types of performance plot, such as "ks", "lift", "roc", "pr". Default c("ks", "roc").
#' @param show_plot Logical value, default TRUE. It means whether to show plot.
#' @param seed An integer. The specify seed is used for random sorting data, default: 186.
#' @return ks, roc, lift, pr
#' @seealso \code{\link{perf_psi}}
#'
#' @examples
#' \dontrun{
#' library(data.table)
#' library(scorecard)
#'
#' # Traditional Credit Scoring Using Logistic Regression
#' # load germancredit data
#' data("germancredit")
#'
#' # rename creditability as y
#' dt <- data.table(germancredit)[, `:=`(
#'   y = ifelse(creditability == "bad", 1, 0),
#'   creditability = NULL
#' )]
#'
#' # woe binning ------
#' bins <- woebin(dt, "y")
#' dt_woe <- woebin_ply(dt, bins)
#'
#' # glm ------
#' m1 <- glm( y ~ ., family = "binomial", data = dt_woe)
#' # summary(m1)
#'
#' # Select a formula-based model by AIC
#' m_step <- step(m1, direction="both")
#' m2 <- eval(m_step$call)
#' # summary(m2)
#'
#' # performance ------
#' # predicted proability
#' dt_woe$pred <- predict(m2, type='response', dt_woe)
#'
#' # performance
#' # only ks & auc values
#' perf_plot(dt_woe$y, dt_woe$pred, show_plot=FALSE)
#'
#' # ks & roc plot
#' perf_plot(dt_woe$y, dt_woe$pred)
#'
#' # ks, lift, roc & pr plot
#' perf_plot(dt_woe$y, dt_woe$pred, type = c("ks","lift","roc","pr"))
#' }
#' @import data.table ggplot2 gridExtra
#' @export
#'
perf_plot <- function(label, pred, title="train", groupnum=20, type=c("ks", "roc"), show_plot=TRUE, seed=186) {
  group = . = good = bad = ks = cumbad = cumgood = value = variable = model = countP = countN = FN = TN = TP = FP = FPR = TPR = precision = recall = NULL # no visible binding for global variable

  # inputs checking
  if (!is.vector(label) | !is.vector(pred)) break
  if (length(label) != length(pred)) break

  # random sort datatable
  set.seed(seed)
  df1 <- data.table(
    label=ifelse(grepl("bad|1", as.character(label)), 1, 0),
    pred=pred
  )[!is.na(label)][sample(1:length(pred))]

  # data, dfkslift ------
  if ("ks" %in% type | "lift" %in% type) {
    if (groupnum == "N") groupnum <- length(pred)

    dfkslift <-
      df1[order(-pred)
          ][, group := ceiling(as.integer(row.names(.SD))/(.N/groupnum))
            ][,.(good = sum(label==0), bad = sum(label==1)), by=group
              ][,`:=`(group= as.integer(row.names(.SD))/.N,
                      good = good/sum(good), bad  = bad/sum(bad),
                      cumgood= cumsum(good)/sum(good), cumbad = cumsum(bad)/sum(bad))
                ][, ks := cumbad - cumgood]

    dfkslift <- rbind(data.table(group=0, good=0, bad=0, cumgood=0, cumbad=0, ks=0), dfkslift)

  }


  # return list
  rt <- list()

  # plot, KS ------
  if ("ks" %in% type) {
    dfks <- dfkslift[ks == max(ks)][order(group)][1]
    # return list
    rt$KS <- round(dfks$ks, 4)
    # print(paste0("KS: ", round(dfks$ks, 4) ))

    if (show_plot == TRUE) {
      pks <- ggplot(melt(dfkslift[,.(group, cumgood, cumbad, ks)], id="group"), aes(x=group, y=value, colour=variable)) +
        geom_line() + coord_fixed() +
        geom_segment(aes(x = dfks$group, y = 0, xend = dfks$group, yend = dfks$ks), colour = "red", linetype = "dashed", arrow=arrow(ends="both", length=unit(.2,"cm"))) +
        labs(x = "% of population", y = "% of total Good/Bad") +
        annotate("text", x=0.50, y=Inf, label="K-S", vjust=1.5, size=6)+
        annotate("text", x=dfks$group, y=dfks$ks, vjust = -0.2, label=paste0("KS: ", round(dfks$ks,4) ), colour = "blue") +
        annotate("text", x=0.20, y=0.80, vjust = -0.2, label="Bad", colour = "black") +
        annotate("text", x=0.80, y=0.55, vjust = -0.2, label="Good", colour = "black") +
        scale_x_continuous(expand = c(0, 0), limits = c(0, 1)) +
        scale_y_continuous(expand = c(0, 0), limits = c(0, 1)) +
        scale_colour_manual(values=c("black", "black", "blue")) +
        theme_bw() + theme(legend.position="none")
    }
  }

  # plot, Lift ------
  if ("lift" %in% type) {
    plift <- ggplot(dfkslift[-1][,.(group, model = bad)], aes(x=group, y=model)) +
      geom_bar(stat = "identity", fill=NA, colour = "black") + coord_fixed() +
      geom_segment(aes(x = 0, y = 1/groupnum, xend = 1, yend = 1/groupnum), colour = "red", linetype = "dashed") +
      labs(x="% of population", y="%of total Bad") +
      annotate("text", x = 0.50, y=Inf, label="Lift", vjust=1.5, size=6)+
      guides(fill=guide_legend(title=NULL)) +
      scale_fill_manual(values=c("white", "grey")) +
      scale_x_continuous(expand = c(0, 0), limits = c(0, 1)) +
      scale_y_continuous(expand = c(0, 0), limits = c(0, 1)) +
      theme_bw() + theme(legend.position=c(0.5, 0.9), legend.direction="horizontal")

  }

  # data, dfrocpr ------
  if ("roc" %in% type | "pr" %in% type) {
    dfrocpr <-
      df1[order(pred)
          ][, .(countpred = .N, countP = sum(label==1), countN = sum(label==0)), by=pred
            ][, `:=`(FN = cumsum(countP), TN = cumsum(countN) )
              ][, `:=`(TP = sum(countP) - FN, FP = sum(countN) - TN)
                ][, `:=`(TPR = TP/(TP+FN), FPR = FP/(TN+FP), precision = TP/(TP+FP), recall = TP/(TP+FN)) ]

  }

  # plot, ROC ------
  if ("roc" %in% type) {
    AUC <- dfrocpr[, sum(TP/(TP+FN)*(FP/(TN+FP)-shift(FP/(TN+FP), fill=0, type="lead")))]
    # return list
    rt$AUC <- round(AUC,4)
    # print(paste0("AUC: ", round(AUC,4)))

    if (show_plot == TRUE) {
      proc <- ggplot(dfrocpr, aes(x=FPR, y=TPR)) +
        geom_ribbon(aes(ymin=0, ymax=TPR), fill="blue", alpha=0.1) +
        geom_line() + coord_fixed() +
        geom_segment(aes(x=0, y=0, xend=1, yend=1), linetype = "dashed", colour="red") +
        annotate("text", x = 0.5, y=Inf, label="ROC", vjust=1.5, size=6) +
        annotate("text", x=0.55, y=0.45, label=paste0("AUC: ", round(AUC,4)), colour = "blue") +
        scale_x_continuous(expand = c(0, 0), limits = c(0, 1)) +
        scale_y_continuous(expand = c(0, 0), limits = c(0, 1)) +
        theme_bw()
    }
  }


  # plot, P-R ------
  if ("pr" %in% type) {
    dfpr <- dfrocpr[precision == recall]
    # print(paste0("BEP: ", round(dfpr$recall, 4)))
    if (show_plot == TRUE) {
      ppr <- ggplot(dfrocpr, aes(x=recall, y=precision)) +
        geom_line() + coord_fixed() +
        geom_segment(aes(x = 0, y = 0, xend = 1, yend = 1), colour = "red", linetype="dashed") +
        labs(x = "Recall", y = "Precision") +
        annotate("text", x = 0.5, y=Inf, label="P-R", vjust=1.5, size=6) +
        scale_x_continuous(expand = c(0, 0), limits = c(0, 1)) +
        scale_y_continuous(expand = c(0, 0), limits = c(0, 1)) +
        theme_bw()
    }
  }


  # export plot
  if (show_plot == TRUE) {
    plist <- paste0("p", type)
    # add title for first plot
    eval(parse(text = paste0(plist[1], " = ", plist[1], " + ggtitle(title)")))

    if (length(plist) == 1) {
      p <- eval(parse(text = plist))
    } else if (length(plist) > 1) {
      # add title for second plot
      title=""
      eval(parse(text = paste0(plist[2:length(plist)], " = ", plist[2:length(plist)], " + ggtitle(title)")))

      # Arrange multiple plots
      p <- eval(parse(
        text = paste0("grid.arrange(", paste0(plist, collapse = ", "), ", nrow=", length(plist) %/% 2,", padding = 0)")
      ))
    }

    # return list
    rt$p <- p
  }

  return(rt)
}

#' PSI
#'
#' \code{perf_psi} calculates population stability index (PSI) based on provided credit score and provides plot of credit score distribution.
#'
#' @param score List of credit score for both actual and expected data sample. For example, score <- list(train = df1, test = df2), both df1 and df2 are dataframe.
#' @param label List of label values for both actual and expected data sample. For example, label <- list(train = df1, test = df2), both df1 and df2 are dataframe. The label values should be 0s and 1s, 0 represent for good and 1 for bad.
#' @param title Title of plot, default "".
#' @param x_limits x-axis limits, default c(0, 800).
#' @param x_tick_break x-axis ticker break, default 100.
#' @param show_plot Logical value, default TRUE. It means whether to show plot.
#' @param seed An integer. The specify seed is used for random sorting data, default 186.
#'
#' @return a dataframe of psi & plots of credit score distribution
#' @seealso \code{\link{perf_plot}}
#'
#' @examples
#' \dontrun{
#' library(data.table)
#' library(scorecard)
#'
#' # Traditional Credit Scoring Using Logistic Regression
#' # load germancredit data
#' data("germancredit")
#'
#' # rename creditability as y
#' dt <- data.table(germancredit)[, `:=`(
#'   y = ifelse(creditability == "bad", 1, 0),
#'   creditability = NULL
#' )]
#'
#' # breaking dt into train and test ------
#' set.seed(125)
#' dt <- dt[sample(nrow(dt))]
#' # rowname of train
#' set.seed(345)
#' rn <- sample(nrow(dt), nrow(dt)*0.6)
#' # train and test dt
#' dt_train <- dt[rn]; dt_test <- dt[-rn];
#'
#' # woe binning ------
#' bins <- woebin(dt_train, "y")
#'
#' # converting train and test into woe values
#' train <- woebin_ply(dt_train, bins)
#' test <- woebin_ply(dt_test, bins)
#'
#' # glm ------
#' m1 <- glm( y ~ ., family = "binomial", data = train)
#' # summary(m1)
#'
#' # Select a formula-based model by AIC
#' m_step <- step(m1, direction="both")
#' m2 <- eval(m_step$call)
#' # summary(m2)
#'
#' # performance ------
#' # predicted proability
#' train_pred <- predict(m2, type='response', train)
#' test_pred <- predict(m2, type='response', test)
#'
#' # ks & roc plot
#' perf_plot(train$y, train_pred, title = "train")
#' perf_plot(train$y, train_pred, title = "test")
#'
#' # score
#' card <- scorecard(bins, m2)
#'
#' # credit score, only_total_score = TRUE
#' train_score <- scorecard_ply(dt_train, card)
#' test_score <- scorecard_ply(dt_test, card)
#'
#' # psi
#' psi <- perf_psi(
#'   score = list(train = train_score, test = test_score),
#'   label = list(train = train[,"y"], test = test[, "y"])
#' )
#' # psi$psi # psi dataframe
#' # psi$p   # plot of score distribution
#'
#' # specifying score range
#' psi_s <- perf_psi(
#'   score = list(train = train_score, test = test_score),
#'   label = list(train = train[,"y"], test = test[, "y"]),
#'   x_limits = c(150, 750),
#'   x_tick_break = 50
#'   )
#'
#' # credit score, only_total_score = FALSE
#' train_score2 <- scorecard_ply(dt_train, card, only_total_score=FALSE)
#' test_score2 <- scorecard_ply(dt_test, card, only_total_score=FALSE)
#'
#' # psi
#' psi2 <- perf_psi(
#'   score = list(train = train_score2, test = test_score2),
#'   label = list(train = train[,"y"], test = test[, "y"])
#' )
#' # psi2$psi # psi dataframe
#' # psi2$p   # plot of score distribution
#' }
#' @import data.table ggplot2 gridExtra
#' @export
#'
perf_psi <- function(score, label = NULL, title="", x_limits=c(100,800), x_tick_break=50, show_plot=TRUE, seed=186) {
  # psi = sum((Actual% - Expected%)*ln(Actual%/Expected%))

  . = A = ae = E = PSI = bad = badprob = badprob2 = bin = bin1 = bin2 = count = distr = logAE = midbin = test = train = y = NULL # no visible binding for global variable
  rt = rt_psi = rt_p = list() # return list
  rt$psi <- NULL
  rt$p <- NULL

  # inputs checking
  if (length(score) != 2) {
    break
  } else {
    if (!is.data.frame(score[[1]]) | !is.data.frame(score[[2]])) break
    if (!identical( names(score[[1]]), names(score[[2]]) )) break

    if (!is.null(label)) {
      if (length(label) != 2) break
      if (!is.data.frame(label[[1]]) | !is.data.frame(label[[2]])) break
      if (!identical( names(label[[1]]), names(label[[2]]) )) break

      if (!identical(names(score), names(label))) break
    }
  }


  # merge score label into one dataframe
  score_names <- names(score[[1]])

  if (!is.null(label)) {
    score[[1]]$y <- label[[names(score)[1]]][,1]
    score[[2]]$y <- label[[names(score)[2]]][,1]

  } else {
    score[[1]]$y <- NA
    score[[2]]$y <- NA

  }
  dt_sl <- cbind(rbindlist(score, idcol = "ae")) # ae refers to 'Actual & Expected'

  # PSI function
  psi <- function(dat) {
    # dat <- copy(dat)[,y:=NULL][complete.cases(dat),]
    AE = NULL

    # dataframe of bin, actual, expected
    dt_bae <- dcast(
      dat[,.(count=.N), keyby=c("ae", "bin")
          ][,distr := count/sum(count), by="ae"][],
      bin ~ ae, value.var="distr", fill = 0
    )

    names_ae <- setdiff(names(dt_bae), "bin")
    dt_bae <- dt_bae[, `:=`(
      A = dt_bae[[names_ae[1]]],
      E = dt_bae[[names_ae[2]]]
    )]

    dt_bae[, `:=`(AE = A-E, logAE = log(A/E))
        ][, `:=`(PSI = AE*logAE)
          ][, `:=`(PSI = ifelse(PSI==Inf, 0, PSI))][, sum(PSI)]
  }


  for ( sn in score_names ) {
    if (length(unique(dt_sl[[sn]])) > 10) {
      # breakpoints
      brkp <- unique(c(
        floor(min(dt_sl[[sn]])/x_tick_break)*x_tick_break,
        seq(x_limits[1]+x_tick_break, x_limits[2]-x_tick_break, by=x_tick_break),
        ceiling(max(dt_sl[[sn]])/x_tick_break)*x_tick_break
      ))

      # random sort datatable
      set.seed(seed)
      dat <- dt_sl[sample(1:nrow(dt_sl))][, c("ae", "y", sn), with = FALSE]

      dat$bin <- cut(dat[[sn]], brkp, right = FALSE, dig.lab = 10, ordered_result = F)

    } else {
      # random sort datatable
      set.seed(seed)
      dat <- dt_sl[sample(1:nrow(dt_sl))][, c("ae", "y", sn), with = FALSE]
      dat$bin <- dat[[sn]]

    }

    # psi ------
    # rt[[paste0(sn, "_psi")]] <- round(psi(dat), 4)
    rt_psi[[sn]] <- data.frame(PSI = round(psi(dat), 4))



    # plot ------
    # distribution of scorecard probability
    if (show_plot) {
      # score distribution and bad probability
      distr_prob <- dat[
        order(bin)
        ][,.(count=.N, bad=sum(y==1)), keyby=c("ae", "bin")
          ][,`:=`(
            distr = count/sum(count),
            badprob=bad/count
          ), by = "ae"][,`:=`(badprob2=badprob*max(distr)), by = "ae"][, `:=`(
            bin1 = as.integer(sub("\\[(.+),(.+)\\)", "\\1", bin)),
            bin2 = as.integer(sub("\\[(.+),(.+)\\)", "\\2", bin))
          )][, midbin := (bin1+bin2)/2 ]


      # plot
      p_score_distr <-
        ggplot(distr_prob) +
        geom_bar(aes(x=bin, y=distr, fill=ae), alpha=0.6, stat="identity", position="dodge") +
        geom_line(aes(x=bin, y=badprob2, group=ae, colour=ae, linetype=ae)) +
        geom_point(aes(x=bin, y=badprob2, colour=ae), shape=21, fill="white") +
        guides(fill=guide_legend(title="Distribution"), colour=guide_legend(title="Probability"), linetype=guide_legend(title="Probability")) +
        scale_y_continuous(expand = c(0, 0), sec.axis = sec_axis(~./max(distr_prob$distr), name = "Bad probability")) +
        labs(x=NULL, y="Score distribution") +
        theme_bw() +
        # theme(legend.position="bottom", legend.direction="horizontal") +
        theme(plot.title=element_text(vjust = -2.5), legend.position=c(1,1), legend.justification=c(1,1), legend.background=element_blank())


      if (title != "" & !is.na(title)) {
        p_score_distr <- p_score_distr + ggtitle(paste0(title, " PSI: ", round(psi(dat), 4)))
      } else {
        p_score_distr <- p_score_distr + ggtitle(paste0(sn, "_PSI: ", round(psi(dat), 4)))
      }

      # rt[[paste0(sn, "_p")]] <- p_score_distr
      rt_p[[sn]] <- p_score_distr

    } # end of show plot
  } # end of for loop
  rt$psi <- rbindlist(rt_psi, idcol = "variable")
  rt$p <- rt_p

  return(rt)
}
