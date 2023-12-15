#!/bin/bash
## Нужно знать логин и пароль в харбор

helm upgrade --install hipster-shop oci://harbor.46.138.241.117.nip.io/library/hipster-shop --version 0.1.0 -n hipster-shop


