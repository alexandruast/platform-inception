import jenkins.model.Jenkins
def sout = new StringBuilder(), serr = new StringBuilder()
def proc = 'tar -cpzf /tmp/jenkins_backup.tar.gz --exclude=config.xml --one-file-system -C {{JENKINS_HOME}} ./jobs ./workspace'.execute()
proc.consumeProcessOutput(sout, serr)
proc.waitForOrKill(4 * 60 * 1000)
