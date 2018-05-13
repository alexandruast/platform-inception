import jenkins.model.Jenkins
println new ProcessBuilder(
  'sh',
  '-c',
  'tar -xpf /tmp/jenkins_backup.tar.gz -C {{JENKINS_HOME}} --numeric-owner'
).redirectErrorStream(true).start().text
