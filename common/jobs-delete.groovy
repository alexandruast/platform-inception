for(job in jenkins.model.Jenkins.theInstance.getAllItems()) {
  job.delete()
}