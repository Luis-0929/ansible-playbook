#!/bin/bash
hash_pw_sha512() {
  local pw="$1"
  openssl passwd -6 "$pw"
}

setPasswords() {
  read -rp "Base alma9 config root password: " alma9_base_user_pass
  read -rp "Root user password: " root_pass
  read -rp "Admin user password: " admin_pass
  read -rp "Ansible user password: " ansible_pass
  read -rp "Podman user password: " podman_pass
  read -s -rp "Your IDM user password: " idm_user_pass; echo

  while true; do
    echo "------------------------"
    echo "Base alma9 root = $alma9_base_user_pass"
    echo "Root user password = $root_pass"
    echo "Admin user password = $admin_pass"
    echo "Ansible user password = $ansible_pass"
    echo "Podman user password = $podman_pass"
    read -rp "Are the above passwords correct? [Y/n] " yn
    echo "------------------------"
    case $yn in
      [nN][oO] | [nN])
        setPasswords
        break
        ;;
      *)
        break
        ;;
    esac
  done
}

setPasswords

echo "Hashing passwords..."

root_pass_hashed="$(hash_pw_sha512 "$root_pass")"
admin_pass_hashed="$(hash_pw_sha512 "$admin_pass")"
podman_pass_hashed="$(hash_pw_sha512 "$podman_pass")"
ansible_pass_hashed="$(hash_pw_sha512 "$ansible_pass")"

random_pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)

vault_template=vault.template
vm_user_vault_tempalte=vault_vm_users.template
vault_pass=../secrets/vault.pass

alma9_base_user_vault=../secrets/alma9-base-user-vault.yaml
idm_user_vault=../secrets/idm-user-vault.yaml
ansible_user_vault=../secrets/ansible-user-vault.yaml
vm_user_passwords_vault=../secrets/vm_user_passwords_vault.yaml

echo "Generating New vault files"

echo "${random_pass}" > "${vault_pass}"

cp "$vault_template" "$alma9_base_user_vault"
sed -i "s,ansible_ssh_pass:,ansible_ssh_pass: ${alma9_base_user_pass},g" "$alma9_base_user_vault"
ansible-vault encrypt --vault-password-file="${vault_pass}" "${alma9_base_user_vault}"

cp "$vault_template" "$idm_user_vault"
sed -i "s,ansible_ssh_pass:,ansible_ssh_pass: ${idm_user_pass},g" "$idm_user_vault"
ansible-vault encrypt --vault-password-file="${vault_pass}" "${idm_user_vault}"

cp "$vault_template" "$ansible_user_vault"
sed -i "s,ansible_ssh_pass:,ansible_ssh_pass: ${ansible_pass},g" "$ansible_user_vault"
ansible-vault encrypt --vault-password-file="${vault_pass}" "${ansible_user_vault}"

cp "$vm_user_vault_tempalte" "$vm_user_passwords_vault"

sed -i "s,admin_passwd:,admin_passwd: ${admin_pass_hashed},g" "$vm_user_passwords_vault"
sed -i "s,root_passwd:,root_passwd: ${root_pass_hashed},g" "$vm_user_passwords_vault"
sed -i "s,podman_passwd:,podman_passwd: ${podman_pass_hashed},g" "$vm_user_passwords_vault"
sed -i "s,ansible_passwd:,ansible_passwd: ${ansible_pass_hashed},g" "$vm_user_passwords_vault"

ansible-vault encrypt --vault-password-file="${vault_pass}" "${vm_user_passwords_vault}"

echo "Done."