import jenkins.model.Jenkins
println new ProcessBuilder(
  'sh',
  '-c',
  'tar -cpf /tmp/jenkins_backup.tar.gz --exclude=config.xml --one-file-system -C {{JENKINS_HOME}} ./jobs'
).redirectErrorStream(true).start().text
