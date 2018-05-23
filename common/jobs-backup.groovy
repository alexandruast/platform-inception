import jenkins.model.Jenkins
println new ProcessBuilder(
  'sh',
  '-c',
  'tar -cpf /tmp/jenkins_backup.tar --exclude="config.xml" --exclude="*_ws-cleanup_*" --one-file-system -C {{JENKINS_HOME}} ./jobs ./workspace'
).redirectErrorStream(true).start().text
