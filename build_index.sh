#!/usr/bin/env bash

# Deletes existing index and recreates it with mapping.

ES_HOST=${1:-"http://localhost:9200"}
INDEX=${2:-siriusxm}

curl -sf -XDELETE ${ES_HOST}/${INDEX}
curl -XPOST ${ES_HOST}/${INDEX} -d '
{
    "settings": {
        "number_of_shards": 5,
        "number_of_replicas": 0,
        "refresh_interval": "5s"
    },
    "mappings": {
        "_default_": {
            "dynamic_templates": [
                {
                    "template_object": {
                        "mapping": {
                            "type": "nested"
                        },
                        "match": "*",
                        "match_mapping_type": "object"
                    }
                },
                {
                    "template_string": {
                        "mapping": {
                            "index": "not_analyzed",
                            "doc_values": true,
                            "type": "string"
                        },
                        "match": "*",
                        "match_mapping_type": "string"
                    }
                },
                {
                    "template_catch_all": {
                        "mapping": {
                            "doc_values": true
                        },
                        "match": "*",
                        "match_mapping_type": "*"
                    }
                }
            ]
        }
    }
}'
