// Configure the Google Cloud provider
provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_name
  region      = var.region
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
  byte_length = 8
}

// A single Compute Engine instance

resource "google_compute_instance" "node" {

  name         = "vm-${random_id.instance_id.hex}"
  machine_type = var.machine_type
  zone         = var.region

  metadata = {
    ssh-keys = "tester2:${file("~/.ssh/id_rsa.pub")}"
  }
  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  // Make sure flask is installed on all new instances for later steps
  // metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python-pip rsync; pip install flask"
  connection {
    type        = "ssh"
    host        = google_compute_instance.node.network_interface.0.access_config.0.nat_ip
    user        = var.ssh_user
    private_key = file(var.private_key_file)
  }
  provisioner "file" {
    source      = "./testnet"
    destination = "./testnet"
  }
    provisioner "file" {
    source      = "./params.json"
    destination = "./params.json"
    }
  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install docker.io -y",
      "sudo add-apt-repository ppa:serokell/tezos -y && sudo apt-get update",
      "sudo apt-get install -y tezos-client",
      "sudo apt-get install -y tezos-node",
      // "sudo apt-get install -y tezos-baker-010-ptgranad",
      // "sudo apt-get install -y tezos-endorser-010-ptgranad",
      // "sudo apt-get install -y tezos-accuser-010-ptgranad",

      "sudo docker run --network host -t -d --name node tezos/tezos-bare:master",
      "sudo docker cp ./testnet node:/home/tezos/testnet",
      "sudo docker exec node tezos-node identity generate",
      "sudo docker exec node sed -i \"s/127.0.0.1//\" ./testnet",
      "sudo docker exec node cat testnet",
      "sudo docker exec node tezos-node config init --network=./testnet",
      "nohup sudo docker exec node tezos-node run --rpc-addr localhost:8732 --bootstrap-threshold=1 --rpc-addr :8733 &",
      "sleep 15",
      "cat nohup.out",



      "sudo docker exec node tezos-client import secret key activator unencrypted:edsk31vznjHSSpGExDMHYASz45VZqXN4DPxvsa4hAyY8dHM28cZzp6",
      "sudo docker exec node tezos-client gen keys baker",
      "sudo docker exec node tezos-client show address baker",
      "genesis_key=\"$( sudo docker exec node tezos-client show address baker  | sed --quiet --expression='s/^.*Public Key: //p')\"",
      "sed -i \"s/key1/$${genesis_key}/\" ./params.json",
      "cat params.json",
      "sudo docker cp ./params.json node:/home/tezos/params.json",

      "sudo docker exec node tezos-client activate protocol PtGRANADsDU8R9daYKAgWnQYAJ64omN1o3KMGVCykShA97vQbvV with fitness 1 and key activator and parameters params.json",

      "sleep 10",
      "cat nohup.out"
    ]
  }


  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }
}





