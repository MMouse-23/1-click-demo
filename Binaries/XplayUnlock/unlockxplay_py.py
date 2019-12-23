import sys
sys.path.insert(0, '/home/nutanix/ncc/bin')
import env
import json
import os
from cluster.utils import genesis_client
 
CLUSTER_MANAGER = "ClusterManager"
client = genesis_client.GenesisApiClient()
 
def enable_service(service):
  service_list = service if isinstance(service, list) else [service]
  arg = {
  "service_list_json": json.dumps({"service_list": service_list})
  }
  ret = client.make_rpc(CLUSTER_MANAGER, enable_service.__name__, arg)
  print ret

def fix_510_bugs():
  directory = os.path.dirname("/home/nutanix/data/email/attachments/")
  if not os.path.exists(directory):
    os.makedirs(directory)
  
  display_metadata_list = [{"field_name":"entity_info", "field_type": "kEntitySearch"}, 
    {"field_name": "vcpu_reduction_count", "field_type": "kInput"},
    {"field_name": "min_vcpu_count", "field_type": "kInput"},
    {"field_name": "cores_per_vcpu_reduction_count", "field_type": "kInput"},
    {"field_name": "min_cores_per_vcpu_count", "field_type": "kInput"}]
  with open('/home/nutanix/config/vulcan/types/vm_remove_cpu.action.json', 'r+') as f:
    type_def = json.load(f)
    type_def["componentInfo"]["displayMetadataList"] = display_metadata_list
    f.seek(0)
    f.write(json.dumps(type_def))
    f.truncate()
 
if __name__ == '__main__':
  fix_510_bugs()
  enable_service("VulcanService")
