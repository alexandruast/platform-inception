import hudson.slaves.EnvironmentVariablesNodeProperty
import jenkins.model.Jenkins

def instance = Jenkins.instance
globalNodeProperties = instance.getGlobalNodeProperties()
envVarsNodePropertyList = globalNodeProperties.getAll(EnvironmentVariablesNodeProperty.class)

newEnvVarsNodeProperty = null
envVars = null

if ( envVarsNodePropertyList == null || envVarsNodePropertyList.size() == 0 ) {
  newEnvVarsNodeProperty = new EnvironmentVariablesNodeProperty();
  globalNodeProperties.add(newEnvVarsNodeProperty)
  envVars = newEnvVarsNodeProperty.getEnvVars()
} else {
  envVars = envVarsNodePropertyList.get(0).getEnvVars()
}

envVarName="{{JENKINS_ENV_VAR_NAME}}"
envVarValue="{{JENKINS_ENV_VAR_VALUE}}"

envVars.put(envVarName, envVarValue)

instance.save()