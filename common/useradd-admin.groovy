import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("{{JENKINS_ADMIN_USER}}","{{JENKINS_ADMIN_PASS}}")
instance.setSecurityRealm(hudsonRealm)

def strategy = new GlobalMatrixAuthorizationStrategy()
strategy.add(Jenkins.ADMINISTER, "{{JENKINS_ADMIN_USER}}")
instance.setAuthorizationStrategy(strategy)

instance.save()
