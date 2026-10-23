resource "local_file" "computed2" {
  filename = "${local.base_dir}/greeting-computed2${local.timestamp_suffix}.txt"
  content  = local.full_greeting
}
