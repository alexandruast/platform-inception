import jenkins.model.Jenkins
println "Safe restarting Jenkins..."
Jenkins.instance.doSafeRestart(null)

