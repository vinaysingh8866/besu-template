#!/bin/bash

# Besu Network - View Logs
# View logs from different components

NAMESPACE="besu-network"

echo "Besu Network - Logs Viewer"
echo ""
echo "Select component to view logs:"
echo "  1. Bootnode"
echo "  2. Validator 0"
echo "  3. Validator 1"
echo "  4. Validator 2"
echo "  5. Validator 3"
echo "  6. RPC Node"
echo "  7. BlockScout"
echo "  8. PostgreSQL"
echo "  9. Redis"
echo "  10. Prometheus"
echo "  11. Grafana"
echo "  12. All pods (summary)"
echo ""
read -p "Enter selection (1-12): " choice

case $choice in
    1)
        echo "Showing Bootnode logs..."
        kubectl logs -f -l app=besu-bootnode -n ${NAMESPACE}
        ;;
    2)
        echo "Showing Validator 0 logs..."
        kubectl logs -f besu-validator-0 -n ${NAMESPACE}
        ;;
    3)
        echo "Showing Validator 1 logs..."
        kubectl logs -f besu-validator-1 -n ${NAMESPACE}
        ;;
    4)
        echo "Showing Validator 2 logs..."
        kubectl logs -f besu-validator-2 -n ${NAMESPACE}
        ;;
    5)
        echo "Showing Validator 3 logs..."
        kubectl logs -f besu-validator-3 -n ${NAMESPACE}
        ;;
    6)
        echo "Showing RPC Node logs..."
        kubectl logs -f -l app=besu-rpc -n ${NAMESPACE}
        ;;
    7)
        echo "Showing BlockScout logs..."
        kubectl logs -f -l app=blockscout -n ${NAMESPACE}
        ;;
    8)
        echo "Showing PostgreSQL logs..."
        kubectl logs -f -l app=blockscout-postgres -n ${NAMESPACE}
        ;;
    9)
        echo "Showing Redis logs..."
        kubectl logs -f -l app=blockscout-redis -n ${NAMESPACE}
        ;;
    10)
        echo "Showing Prometheus logs..."
        kubectl logs -f -l app=prometheus -n ${NAMESPACE}
        ;;
    11)
        echo "Showing Grafana logs..."
        kubectl logs -f -l app=grafana -n ${NAMESPACE}
        ;;
    12)
        echo "Showing all pods status..."
        kubectl get pods -n ${NAMESPACE}
        echo ""
        echo "Recent events:"
        kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -20
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac
