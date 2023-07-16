HELP="Usage: \n
\texp-setup --help\n 
\texp-setup --run-resource-measure <ML_SIZE> <REPLICAS>\n
\texp-setup --run-workflow-measure <ML_SIZE> <REPLICAS>\n
\t\t ML_SIZE = {SMALLL,LARGE}\n"

COMMAND=$1

function run_experiment_measure {
   
    export EXP_TYPE=$1
    export EXP_SIZE=$2
    export CONF="CONF"
    export EXP_FINAL=$CONF-$1-$2
    NUM_REPLICAS=$3
    
    folder=exp-measure-${EXP_TYPE,,}-${EXP_SIZE,,}-$(date +%d-%m-%Y"-"%H:%M:%S)
    mkdir $folder

    network_measure_file=./network_measure.log

    #echo "TYPE, LATENCY, THROUGHPUT_SPEED, THROUGHPUT_TIME" >> $network_measure_file
    #echo "TYPE, ID, PID, TIME, CPU, %CPU_PS_AUX, LEN_CPU, MEMORY_USS, MEMORY_PSS, MEMORY_RSS, %MEMORY_PS_AUX, MEMORY_VSZ_PS_AUX , MEMORY_RSS_PS_AUX" >> ./participant_measurer.log 

    echo ""
    echo "[E_INFO] Prepare Scone Sessions"
    echo ""

    # prepare
    envsubst '$EXP_FINAL' < participant_a_exp.yaml > participant_a_exp_sub.yaml
    envsubst '$EXP_FINAL' < participant_b_exp.yaml > participant_b_exp_sub.yaml
    for replica in $(seq 1 $NUM_REPLICAS); do

        echo ""
        echo "=========================================="
        echo "[E_INFO] Resource Measure"
        echo "[E_INFO] Replica $replica / $NUM_REPLICAS"
        echo "=========================================="
        echo ""

        kubectl apply -f participant_b_exp/deploy.yaml -n my-app
        sleep 10
        PARTICIPANT_B_POD=$(kubectl get pods -n my-app -o=jsonpath='{.items[0].metadata.name}' -l app=participantb)

        echo "Waiting Participant B is ready"

        while [[ $(kubectl get pods $PARTICIPANT_B_POD -n my-app -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
            sleep 1
            PARTICIPANT_B_POD=$(kubectl get pods -n my-app -o=jsonpath='{.items[0].metadata.name}' -l app=participantb)
        done

        sleep 15

        envsubst '$EXP_TYPE $EXP_SIZE' < participant_a_exp/session_template.yaml > participant_a_exp/session.yaml


        kubectl apply -f participant_a_exp/deploy.yaml -n my-app
        sleep 10
        echo "Waiting Participant A is ready"
        
        PARTICIPANT_A_POD=$(kubectl get pods -n my-app -o=jsonpath='{.items[0].metadata.name}' -l app=participanta)

        while [[ $(kubectl get pods $PARTICIPANT_A_POD -n my-app -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
            sleep 1
            PARTICIPANT_A_POD=$(kubectl get pods -n my-app -o=jsonpath='{.items[0].metadata.name}' -l app=participanta)
        done

        sleep 2
        
        participant_a=$(kubectl logs $PARTICIPANT_A_POD -n my-app -c participanta)

        while true;
        do    
            if kubectl logs $PARTICIPANT_A_POD -n my-app -c participanta | grep -q "FINISHED"; then
                break
            fi
        done


        echo ""
        echo "[E_INFO] Saving data"
        echo ""

        kubectl logs $PARTICIPANT_A_POD -n my-app -c participanta > $folder/participant_a_native_$replica.log

        # RESTART_COUNT_PARTICIPANT_A_POD=$(kubectl get pod $PARTICIPANT_A_POD -n my-app -o=jsonpath='{.status.containerStatuses[0].restartCount}')
        
        # if [ "$RESTART_COUNT_PARTICIPANT_A_POD" -gt 0 ]; then
        #     kubectl logs $PARTICIPANT_A_POD -n my-app -c participanta --previous > $folder/participant_a_$replica.log
        # else
        #     kubectl logs $PARTICIPANT_A_POD -n my-app -c participanta > $folder/participant_a_$replica.log
        # fi

        echo "$(kubectl logs $PARTICIPANT_A_POD -n my-app -c measurer)" >> ./participant_measurer.log

        LATENCY=$(kubectl logs $PARTICIPANT_A_POD -n my-app | grep "LATENCY:" | cut -d' ' -f 2)
		THROUGHPUT_SPEED=$(kubectl logs $PARTICIPANT_A_POD -n my-app  | grep "THROUGHPUT_SPEED:" | cut -d' ' -f 2)
        THROUGHPUT_TIME=$(kubectl logs $PARTICIPANT_A_POD -n my-app  | grep "THROUGHPUT_TIME:" | cut -d' ' -f 2)

        echo "$EXP_FINAL, $LATENCY, $THROUGHPUT_SPEED, $THROUGHPUT_TIME" >> $network_measure_file

        echo "$(kubectl logs $PARTICIPANT_B_POD -n my-app -c measurer)" >> ./participant_measurer.log
        kubectl logs $PARTICIPANT_B_POD -n my-app -c participantb > $folder/participant_b_native_$replica.log

    
        echo ""
        echo "[E_INFO] Delete resources"
        echo ""

        rocna uninstall my-app

        sleep 5


    done
}

function delete_scone_components {
    kubectl delete namespace scone 
}

case $COMMAND in
--help) echo -e $HELP ;;
--init) init $2;;
--prepare) prepare;;
--run-experiment-measure) run_experiment_measure $2 $3 $4;;
--uninstall) delete_remaining_resources $2;;
*) echo -e "Invalid Option!\n" && echo -e $HELP ;;
esac
