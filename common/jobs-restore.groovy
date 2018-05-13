import jenkins.model.Jenkins
def sout = new StringBuilder(), serr = new StringBuilder()
def proc = 'tar -xpzf /tmp/jenkins_backup.tar.gz -C {{JENKINS_HOME}} --numeric-owner'.execute()
proc.consumeProcessOutput(sout, serr)
proc.waitForOrKill(4 * 60 * 1000)
