locals {
  file_hashes = {
    for path in sort(fileset(var.chart_directory, "**")) :
    path => filebase64sha512("${var.chart_directory}/${path}")
  }

  hash = base64sha512(jsonencode(local.file_hashes))
}
