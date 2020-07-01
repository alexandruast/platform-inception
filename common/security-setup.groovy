import jenkins.model.Jenkins
import hudson.security.csrf.DefaultCrumbIssuer
import javaposse.jobdsl.plugin.GlobalJobDslSecurityConfiguration
import jenkins.model.GlobalConfiguration
import org.jenkinsci.plugins.workflow.flow.GlobalDefaultFlowDurabilityLevel
import org.jenkinsci.plugins.workflow.flow.FlowDurabilityHint

instance = Jenkins.instance

// println "Disable CLI over remoting"
// instance.getDescriptor("jenkins.CLI").get().setEnabled(false)

// Disable agent protocols, except for protocol 4
println "Disable unsafe agent protocols"
Set<String> agentProtocolsList = ['JNLP4-connect', 'Ping']
if(!instance.getAgentProtocols().equals(agentProtocolsList)) {
  instance.setAgentProtocols(agentProtocolsList)
}

// Disable agent to master security subsystem and dismiss the warning
println "Disable agent to master security subsystem and dismiss the warning"
def rule = instance.getExtensionList(jenkins.security.s2m.MasterKillSwitchConfiguration.class)[0].rule
if(!rule.getMasterKillSwitch()) {
  rule.setMasterKillSwitch(true)
}
instance.getExtensionList(jenkins.security.s2m.MasterKillSwitchWarning.class)[0].disable(true)

println "Enable CSRF protection"
if(instance.getCrumbIssuer() == null) {
  instance.setCrumbIssuer(new DefaultCrumbIssuer(true))
}

println "Disable script security for Job DSL scripts"
GlobalConfiguration.all().get(GlobalJobDslSecurityConfiguration.class).useScriptSecurity=false
GlobalConfiguration.all().get(GlobalJobDslSecurityConfiguration.class).save()

println "Disable sending usage statistics to Jenkins Project"
instance.setNoUsageStatistics(true)

println "PERFORMANCE_OPTIMIZED mode set for Pipelines"
instance.getExtensionList(GlobalDefaultFlowDurabilityLevel.DescriptorImpl.class)[0].setDurabilityHint(FlowDurabilityHint.PERFORMANCE_OPTIMIZED)

instance.save()
