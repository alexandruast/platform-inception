#!/usr/bin/env bash
# Copy the bundled key to all machines - For Demo/Sandbox purposes only!
set -eEo pipefail
trap 'RC=$?; echo [error] exit code $RC running $BASH_COMMAND; exit $RC' ERR

SANDBOX_PEM="$(cat <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA5WaoYTGBXzQw77QiKHUUtR4Xt3bspwKnKp1/MC8LPz/7yKBi
+zPk4abi4HE7X6hQ5NgNYRADLDSdgUmU6Bs5rd1q976dGBXRjYbOZUk14ChEDtrS
eXTEEKF+heyUQegybJ1BJmMELljkTNicLvLUpHxjJTV3GV8fGTBFRYL/9iQ9TV6C
E6ooBMU9rD1wjSyG7VW8tFLypueOth5oWPKEVb/yMaX7SAqFce0IoD2eGMUrCjlB
KKuvpz8WqrFC3lTHkTZkmMO2mnyyZc6U1EKdtsasK27ppHzUb0ZBMc3Tn1y+SeOU
jRCHVSWQrnm/Z330j7oE0KIMrxu+bDkwwLfPLQIDAQABAoIBAQCLfA078+cPJWPw
DF6MrQwnSKHxGy2wKyvL/LH+cUxsbBJDnkoxJg+wqVHgWNlaQ7TUQQ55i0vykBeJ
Kl2ReCRtNGm7NDq/D104qdRLv+UzZChlw+YglcA1wIx3EC/hlzc51bBsj95V9BT1
KOxmm55yWXPLhyPg2HbHURN9vba3SZEF/hF/tLjK/AWZ43TY6FqP4/iXyK1TwWhi
TmohfPjXP5fKMftXZjLtpJevekObVICK2zPA0zf6/L+ShHTfRt7TTUM49vRcYGeW
/PEXl/7wWuY6fyKewMzU0a4ISzXzyXhac2y9pdhjYBYTWWUPQUTdkrcmwIXfoTWn
aJZcXnPdAoGBAPWVcJIfQb95M7I2JmlLcjeY8jnPwVGpMRFdgXSX7ffiBFMPSyHL
zLmGuhoE9/W5HDua1FqgJemLuq7JcqYNjurSeH4nDbj6tTxAWBWVutFs6PypNgM1
Q389x6lWTHIR7vK+MGq2bVTjXrWxgYrNxT4EDoAFb0G8alm9l4kdZx6nAoGBAO8h
gUfiiL6u9f89Xq+nP7nIyvBLAhxBv1QZDYcnEqDkg6c+MvU6ra3hRSfSCgb61KCg
ZL+0dvEGzqJo1at/JD8p2/S0XigAt1fhER8xHBD5cRlgt6tMyYpmxH1w60iEZMft
6k0ycVTvUQMx234sWlv74pUveGBRO1BQNM3FyFILAoGAPqtH8sHvMUFoo82Vt8D9
AJsTFRWjK4eVcez+oBY1L9CJcfixH4q2T5HF4+XosNfwEHXOQuIjSpnRpdDaZO2I
zvuuq+KjadTwctOoprly1waH3hIAKolpFAtb7CaNk35oD6HhERpEhCkRfiQx/o3M
C6tVV+4LGidOrF/pT6AlNHkCgYAxMWlRCm8rGv8MNOnHpNZdN8tXx3Z1rajYehbo
WMdiReA3hXoiLKISBSee23yolu0q5hQTw+I8DzRvALYEA7HHNKtFGd3MyOjusSQ+
kHG/pDD6EYV3PeKwEBgX3iTo1COPZYgvvVLHMDwwNg97U1B7X8PrAMr4tX1INlfG
hQuCpQKBgQDeF9ImA1i7AvVf8v5lccQLlSfeQ/+cUqiRHPhDdVi0c7KO349cWRwC
3tyGQGjm77jDGScosSSHiBAieDkVm/rTyw/gAazpWfR3O70X2naM9dlk8Sshv435
9ZknpCOdrcUI/SXiuHyHtGL6GtIuhreUAcjsOJqXlf+n+nvOZZc1zw==
-----END RSA PRIVATE KEY-----
EOF
)"

mkdir -p "$HOME/.ssh/"
echo "${SANDBOX_PEM}" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
echo "$(ssh-keygen -y -f "$HOME/.ssh/id_rsa") ansible-sandbox" > $HOME/.ssh/id_rsa.pub
SANDBOX_PUBLIC_KEY="$(cat $HOME/.ssh/id_rsa.pub)"
if ! grep "${SANDBOX_PUBLIC_KEY}" "$HOME/.ssh/authorized_keys" > /dev/null 2>&1; then
  mkdir -p "$HOME/.ssh"
  echo "${SANDBOX_PUBLIC_KEY}" >> "$HOME/.ssh/authorized_keys"
fi
