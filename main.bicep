@description('Name for the container group')
param name string = 'unificontainergroup'

@description('Name for the container')
param containerName string = 'unificontainer'

@description('Name for the image')
//param imageName string = 'lscr.io/linuxserver/unifi-controller:latest'
param imageName string = 'docker.io/jacobalberty/unifi:latest'

@description('Name for the data volume')
param volumeName string = 'volume1'

@description('Name for the virtual network')
param virtualNetworkName string = 'vnet1'

//@description('Name for the container network profile')
//param containerGroupNetworkProfileName string = 'containerNetworkProfile'

@description('Name for the virtual network subnet')
param subnetName string = 'subnet1'

@description('Name for the Network Security Group')
param nsgName string = 'inboundNsg'

//@description('The DSN name label')
//param dnsNameLabel string = 'unificontainer'

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

@description('On-prem public IP to use in NSG, required')
param pubIp string

@description('Storage account name')
var storageAccountName = 'data${uniqueString(resourceGroup().id)}'

@description('Private subnet name')
var privSubnet = 'private${subnetName}'

@description('Public subnet name')
var pubSubnet = 'public${subnetName}'

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

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: privSubnet
        properties: {
          addressPrefix: '10.2.0.0/24'
          delegations: [
            {
              name: 'DelegationService'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      {
        name: pubSubnet
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

/*resource containerGroupNetworkProfile 'Microsoft.Network/networkProfiles@2021-02-01' = {
  name: containerGroupNetworkProfileName
  location: location
  properties: {
    containerNetworkInterfaceConfigurations: [
      {
        name: 'containerGroupNetworkProfileInterface'
        properties: {
          ipConfigurations: [
            {
              name: 'containerGroupNetworkProfileInterfaceIPConfiguration'
              properties: {
                subnet: {
                  id: virtualNetwork.properties.subnets[0].id
                }
              }
            }
          ]
        }
      }
    ]
  }
}*/

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow_Unifi_ports_from_onprem_IP_to_LB'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8443'
            '3478'
            '8080'
            '10001'
          ]
          sourceAddressPrefix: pubIp
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
     //COMMENT OUT Rules for Application Gateway as documented here: https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-faq
      {
        name: 'Allow_GWM'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow_AzureLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
} // maybe not needed

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
      //type: 'Public'
      type: 'Private'
      //dnsNameLabel: dnsNameLabel
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
          shareName: 'unifibackups'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
        //secret: {
          //sslCertificateData: sslCertificateData
          //sslCertificatePwd: base64(sslCertificatePwd)
        //}
      }
    ]
    //networkProfile: {
      //id: containerGroupNetworkProfile.id
    //}
  }
}
