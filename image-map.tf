

# This mapping file has entries for symphony multicluster images
# These are images for smc nodes (primary, secondary, secondary-candidate)
locals {
  image_region_map = {
    "hpcc-slurm-management-v1-03may23" = {
      "ca-tor"  = "r038-ea9f18df-1c83-4619-b8b3-c889388ddd32"
      "br-sao"  = "r042-0f4e1794-4b23-4efa-8685-95c9dc02a79c"
      "us-east" = "r014-5c7f43d7-05a1-4f38-9bec-f24f6bf549c0"
      "us-south"= "r006-f5813544-f398-4e9d-8b9b-67378b968c47"
      "jp-osa"  = "r034-d653425f-182e-4667-8dce-b1ef6c623962"
      "jp-tok"  = "r022-8439a084-677c-476a-aca3-be568d37605b"
      "au-syd"  = "r026-0cd28756-4726-464e-a26d-9c6c54f29abd"
      "eu-de"   = "r010-43a70ff6-471e-4b3c-8710-132c254d42be"
      "eu-gb"   = "r018-bb2c621d-3ee5-42b6-9047-362fee6a7b16"
    }
  }
}