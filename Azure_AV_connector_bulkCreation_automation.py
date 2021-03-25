import sys, requests, datetime, os, time, yaml, json, csv, base64, getpass

def Passwords_Secrets():
    try:
        Qualys_Passwd = getpass.getpass(prompt='Qualys Password: ')
        AzureAuthKey = getpass.getpass(prompt='Azure Authentication Key: ')
    except Exception as error:
        print('ERROR', error)
    return Qualys_Passwd, AzureAuthKey

def config():
    with open('config.yml', 'r') as config_settings:
        config_info = yaml.load(config_settings, Loader=yaml.SafeLoader)
        username = str(config_info['defaults']['username']).rstrip()
        directoryId = str(config_info['defaults']['directoryId']).rstrip()
        applicationId = str(config_info['defaults']['applicationId']).rstrip()
        URL = str(config_info['defaults']['baseurl']).rstrip()

        if username == '' or URL == '' or directoryId == '' or applicationId == '':
            print("Config information in ./config.yml not configured correctly. Exiting...")
            sys.exit(1)
    return username, URL, directoryId, applicationId


def Post_Call(username, password, URL, data_connector):
    usrPass = str(username) + ':' + str(password)
    usrPassBytes = bytes(usrPass, "utf-8")
    b64Val = base64.b64encode(usrPassBytes).decode("utf-8")
    headers = {
        'Accept': '*/*',
        'content-type': 'text/xml',
        'X-Requested-With': 'curl',
        'Authorization': "Basic %s" % b64Val

    }

    r = requests.post(URL, data=data_connector, headers=headers)
    return r.raise_for_status()


def Add_Azure_Connector():
    password, azure_authentication_key = Passwords_Secrets()
    username, URL, directoryId, applicationId = config()
    URL = URL + "/qps/rest/2.0/create/am/azureassetdataconnector"

    print('------------------------------Azure Connectors--------------------------------')
    if not os.path.exists("debug"):
        os.makedirs("debug")
    debug_file_name = "debug/debug_file" + time.strftime("%Y%m%d-%H%M%S") + ".txt"
    debug_file = open(debug_file_name, "w")
    debug_file.write('------------------------------Azure Connectors--------------------------------' + '\n')
    with open('Azure_CONNECTOR_INFO.csv', 'rt') as connector_info_file:
        reader = csv.Dictreader(connector_info_file)
        read_info_file = list(reader)
        connector_info_file.close()
    counter = 0
    for i in read_info_file:
        counter += 1
        SubscriptionId = i['SubscriptionId']
        ConnectorName = i['ConnectorName']
        Modules = i['Modules']
        print(str(counter) + ' : Azure Connector')
        debug_file.write(str(counter) + ' : Azure Connector' + '\n')
        print('---' + 'Subscription Id : ' + str(SubscriptionId))
        print('---' + 'Connector Name : ' + str(ConnectorName))
        print('---' + 'Modules : ' + str(Modules))
        debug_file.write('---' + 'Subscription Id : ' + str(SubscriptionId) + '\n')
        debug_file.write('---' + 'Connector Name : ' + str(ConnectorName) + '\n')
        debug_file.write('---' + 'Modules : ' + str(Modules) + '\n')

        module_list = i['Modules'].split()
        activate_module = ""
        for module in module_list:
            activate_module += "<ActivationModule>{0}</ActivationModule>".format(str(module))
        xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><ServiceRequest><data><AzureAssetDataConnector><name>{0}</name><authRecord><applicationId>{1}}</applicationId><directoryId>{2}</directoryId><subscriptionId>{3}</subscriptionId><authenticationKey>{4}</authenticationKey></authRecord><activation><add>{5}</add></activation></AzureAssetDataConnector></data></ServiceRequest>".format(
            Connector_Name, applicationId, directoryId, azure_authentication_key, activate_module, )

        try:
            Post_Call(username, password, URL, xml)
            print(str(counter) + ' : Connector Added Successfully')
            print('-------------------------------------------------------------')
            debug_file.write(str(counter) + ' : Connector Added Successfully' + '\n')

        except requests.exceptions.HTTPError as e:  # This is the correct syntax
            print(str(counter) + ' : Failed to Add Azure Connector')
            print(e)
            print('-------------------------------------------------------------')
            debug_file.write(str(counter) + ' : Failed to Add Azure Connector' + '\n')
            debug_file.write(str(e) + '\n')

    debug_file.close()


Add_Azure_Connector()