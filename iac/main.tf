resource "random_string" "random" {
  count       = 2
  length      = 6
  min_numeric = 6
}
