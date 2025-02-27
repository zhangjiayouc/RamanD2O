## filter low quality SCRS

SCRS_filter <- function(input_dir, output_dir) {
  setwd("./")
  dir.create(output_dir)

  filenames <- list.files(input_dir, pattern = "*.txt")
  cat(
    "INFO:",
    length(filenames),
    "spectrum files detected!",
    sep = " ",
    fill = T
  )
  # Read or SCRS txt files into a dataframe
  raw_dataframe <-
    read.txt.Renishaw(paste0(input_dir, "/", filenames[1]), data = "spc")
  for (filename in filenames[-1]) {
    temp <-
      read.txt.Renishaw(paste0(input_dir, "/", filename), data = "spc")
    raw_dataframe <- rbind(raw_dataframe, temp)
  }

  data_hyperSpec <- raw_dataframe
  # Filter based on minimum intensity
  data_hyperSpec_spc_min <- apply(data_hyperSpec$spc, 1, min)
  data_hyperSpec$data_hyperSpec_spc_min <- data_hyperSpec_spc_min
  data_hyperSpec <-
    data_hyperSpec[data_hyperSpec$data_hyperSpec_spc_min >= 15]
  plot(data_hyperSpec, "spcprctl5")
  cat(
    "INFO:",
    length(data_hyperSpec$filename),
    "spectra left after minimum intensity filtering!",
    sep = " ",
    fill = T
  )

  # Filter low quality SCRS
  good_data_baseline_normalize <- data_hyperSpec
  wls <- wl(data_hyperSpec)
  if (wls[length(wls)] >= 3099) {
    data_baseline <- data_hyperSpec[, , c(1730 ~ 3099)] - # 3151 Horiba
      spc.fit.poly(data_hyperSpec[, , c(1730 ~ 2065, 2300 ~ 2633, 2783, 3099)], data_hyperSpec[, , c(1730 ~ 3099)], poly.order = 3)
    # spc.fit.poly.below (data_hyperSpec, data_hyperSpec, poly.order = 2)#3151 Horiba
    plot(data_baseline)

    factors <-
      1 / apply(data_baseline[, , 2900 ~ 3050], 1, max) # normalize based on mean value of C-H peak
    data_baseline_normalization <-
      sweep(data_baseline, 1, factors, "*")
    data_baseline_normalization <- data_baseline_normalization
    plot(data_baseline_normalization)
    data_baseline_normalization_df <-
      cbind(
        select(as.data.frame(data_baseline_normalization), -spc, -.row),
        as.data.frame(data_baseline_normalization$spc)
      )
    good_data_baseline_normalize <- filter(
      data_baseline_normalization_df,
      apply(abs(data_baseline_normalization_df[, 5:75]), 1, mean) < 0.2,
      apply(abs(data_baseline_normalization_df[, 5:75]), 1, sd) < 0.2
    )
    cat(
      "INFO:",
      length(good_data_baseline_normalize$filename),
      "spectra left after C/D filtering!",
      sep = " ",
      fill = T
    )
  }

  # output high quality SCRS
  data_postfilter <-
    data_hyperSpec[data_hyperSpec$filename %in% good_data_baseline_normalize$filename] # output raw SCRS
  for (i in seq_len(nrow(data_postfilter))) {
    Cells <- t(data_postfilter[i, ]$spc)
    write.table(
      Cells,
      paste0(output_dir, "/", basename(data_postfilter[i, ]$filename)),
      row.names = T,
      col.names = F,
      quote = F,
      sep = "\t"
    )
  }

  # Done!
}
