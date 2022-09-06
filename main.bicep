@description('Name for the container group')
param name string = 'unificontainergroup'

@description('Name for the container')
param containerName string = 'unificontainer'

@description('Name for the image')
param imageName string = 'lscr.io/linuxserver/unifi-controller:latest'
//param imageName string = 'docker.io/jacobalberty/unifi:latest'

@description('Name for the data volume')
param volumeName string = 'volume1'

@description('The DSN name label')
param dnsNameLabel string = 'unificontainer'

//@description('Base-64 encoded authentication PFX certificate.')
//@secure()
//param sslCertificateData string

//@description('Base-64 encoded password of authentication PFX certificate.')
//@secure()
//param sslCertificatePwd string

//@description('Port to open on the container and the public IP address.')
//param port int = 443

@description('The number of CPU cores to allocate to the container.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 1

@description('Location for all resources.')
param location string = resourceGroup().location

//@description('On-prem public IP to use in NSG, required')
//param pubIp string

@description('Storage account name')
var storageAccountName = 'data${uniqueString(resourceGroup().id)}'

@description('Storage Account for persistent data')
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    accessTier: 'Hot'
  }
}

@description('File Share for persistent data')
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: '${storageAccount.name}/default/unifibackups'
  properties: {
    shareQuota: 1
  }
}

resource containergroup 'Microsoft.ContainerInstance/containerGroups@2020-11-01' = {
  name: name
  location: location
  properties: {
    containers: [
      {
        name: containerName
        properties: {
          image: imageName
          ports: [
            {
              port: 8443
              protocol: 'TCP'
            }
            {
              port: 3478
              protocol: 'UDP'
            }
            {
              port: 8080
              protocol: 'TCP'
            }
            {
              port: 10001
              protocol: 'UDP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          volumeMounts: [
            {
              name: volumeName
              mountPath: '/unifibackups'
              readOnly: false
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          protocol: 'TCP'
          port: 8443
        }
        {
          protocol: 'UDP'
          port: 3478
        }
        {
          protocol: 'TCP'
          port: 8080
        }
        {
          protocol: 'UDP'
          port: 10001
        }
      ]
    }
    volumes: [
      {
        name: volumeName
        azureFile: {
          shareName: 'unifidata'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
        //secret: {
          //sslCertificateData: sslCertificateData
          //sslCertificatePwd: base64(sslCertificatePwd)
        //}
      }
    ]
  }
}


