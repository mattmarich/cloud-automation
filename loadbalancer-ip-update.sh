#!/bin/bash
token=""
lookup_file="/tmp/zone_ids-and-zone_names"

a_records=$(cat <<EOF
subdmain.somedomain.com
anotherdomain.com
yetanother.lol
EOF
)

ip=`doctl compute load-balancer list | grep 'entry_port:80' | grep 'entry_port:443' | awk {'print $2'}`

# output zone ids and zone names to lookup file
curl --silent -X GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Content-Type:application/json" \
     -H "Authorization: Bearer $token" | \
     jq -c '.result[] | {id:.id, name: .name}' | \ 
     tr -d '"' | perl -pe 's/{id://g' | perl -pe 's/name://g' | tr -d '}' > $lookup_file

for a_record in `echo $a_records`
do
  domain_name=`echo $a_record | awk -F '.' {'print $(NF-1)"."$NF'}`
  update_record=`echo $a_record | awk -F '.' {'print $1'}`
  zone_id=`grep $domain_name $lookup_file | cut -d ',' -f 1`
  update_record_id=`curl --silent -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$update_record" \
                                  -H "Content-Type:application/json" \
                                  -H "Authorization: Bearer $token" | \
                                  jq -c '.result[] | .id' | tr -d '"'`
  curl --silent -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$update_record_id" \
                -H "Content-Type:application/json" \
                -H "Authorization: Bearer $token" \
                --data '{"type":"A","name":"'$update_record'","content":"'$ip'","ttl":120,"proxied":true}'
done
