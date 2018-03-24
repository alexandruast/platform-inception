import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret

domain = Domain.global()

def store = Jenkins.instance.getExtensionList(
    com.cloudbees.plugins.credentials.SystemCredentialsProvider
)[0].getStore()

def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
    org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl.class,
    Jenkins.instance
)

credential_id="{{JENKINS_CREDENTIAL_ID}}"
credential_desc="{{JENKINS_CREDENTIAL_DESCRIPTION}}"
credential_secret="{{JENKINS_CREDENTIAL_SECRET}}"

def c = creds.findResult { it.id == credential_id ? it : null }

if ( c ) {
    println "found existing credential ${c.id}"
    // perform update
    def result = store.updateCredentials(
        com.cloudbees.plugins.credentials.domains.Domain.global(), 
        c, 
        new StringCredentialsImpl(
            CredentialsScope.GLOBAL,
            credential_id,
            credential_desc,
            Secret.fromString(credential_secret))
        )

    if (result) {
        println "credential ${c.id} updated successfuly"
    } else {
        println "failed to update credential ${c.id}"
    }
} else {
    // create new credential
    secretText = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    credential_id,
    credential_desc,
    Secret.fromString(credential_secret))
    store.addCredentials(domain, secretText)
    println "created new credential ${credential_id}"
}
