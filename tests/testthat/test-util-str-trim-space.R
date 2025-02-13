test_that("Replace double space", {
  df <- data.frame(
    col = c("a  b", "b  c", "c  d")
  )
  df_correct <- data.frame(
    col = c("a b", "b c", "c d")
  )
  df_replaced <- str_trim_space(df, col)
  expect_equal(df_replaced, df_correct)
})
