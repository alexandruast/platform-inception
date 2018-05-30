import jenkins.model.Jenkins
import hudson.security.ACL

Jenkins.instance.doQuietDown()

// Wake up after an async wait
Thread.start {
  // doCancelQuietDown requires admin privileges
  ACL.impersonate(ACL.SYSTEM)
  // Sleep no more than 10 minutes, enough for maintenance scripts to finish
  Thread.sleep(10 * 60 * 1000)
  Jenkins.instance.doCancelQuietDown()
}