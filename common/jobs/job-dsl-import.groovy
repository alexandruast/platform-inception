import jenkins.model.Jenkins
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec
import javaposse.jobdsl.plugin.*
import hudson.slaves.EnvironmentVariablesNodeProperty

jenkins = Jenkins.instance

globalNodeProperties = jenkins.getGlobalNodeProperties()
envVarsNodePropertyList = globalNodeProperties.getAll(EnvironmentVariablesNodeProperty.class)
envVars = envVarsNodePropertyList.get(0).getEnvVars();

envVars.each{
  if (it.key == "JENKINS_SCOPE") {
    platform_scope = it.value
  }
}

job_name = "system-${platform_scope}-job-seed"
job_description = "Dynamically created by jenkins-setup\nAny changes to this item will be overwritten without notice."
git_repository = 'https://github.com/alexandruast/platform-inception'
git_branch = '*/devel'
set_targets = [
  "${platform_scope}/jobs/job-dsl/**/*.groovy",
  "common/jobs/job-dsl/group_all/**/*.groovy",
  "common/jobs/job-dsl/group_clusters/**/*.groovy"
].join('\n')

// Delete existing job if exists
jenkins.getItems().each {
  if (it.name == job_name) {
    it.delete()
  }
}

job = jenkins.createProject(FreeStyleProject, job_name)

job.setDescription(job_description)

job.scm = new GitSCM(git_repository)
job.scm.branches = [new BranchSpec(git_branch)]

job.getBuildersList().clear()

dslBuilder = new ExecuteDslScripts()
dslBuilder.setTargets(set_targets)
dslBuilder.setRemovedJobAction(RemovedJobAction.DISABLE)
dslBuilder.setRemovedViewAction(RemovedViewAction.IGNORE)
dslBuilder.setLookupStrategy(LookupStrategy.JENKINS_ROOT)

job.createTransientActions()
job.getBuildersList().add(dslBuilder)
job.getPublishersList().add(dslBuilder)

job.save()
