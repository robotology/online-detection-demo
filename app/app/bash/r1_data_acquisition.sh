
 #!/bin/bash

#######################################################################################
# HELP
#######################################################################################
usage() {
cat << EOF
***************************************************************************************
R1 Interaction SCRIPTING
Author:  Vadim Tikhanoff   <vadim.tikhanoff@iit.it>

This script scripts through the commands available for R1 to do a data acquisition 
sequence for the active learning detection in the wild

USAGE:
        $0 options

***************************************************************************************
OPTIONS:

***************************************************************************************
EXAMPLE USAGE:

***************************************************************************************
EOF
}

#######################################################################################
# HELPER FUNCTIONS
#######################################################################################

wait_till_quiet() {
    sleep 0.3
    isSpeaking=$(echo "stat" | yarp rpc /iSpeak/rpc)
    while [ "$isSpeaking" == "Response: speaking" ]; do
        isSpeaking=$(echo "stat" | yarp rpc /iSpeak/rpc)
        sleep 0.1
        # echo $isSpeaking
    done
    echo "I'm not speaking any more :)"
    echo $isSpeaking
}

speak() {
    echo "\"$1\"" | yarp write ... /iSpeak
}

go_home_helper() {
    go_home_helperR $1
    go_home_helperL $1
}

go_home_helperL()
{
    echo "ctpq time $1 off 0 pos (-10.0 10.0 10.0 45.0 -1.6 0.0 0.0 0.0)" | yarp rpc /ctpservice/left_arm/rpc
}

go_home_helperR()
{
    echo "ctpq time $1 off 0 pos (-10.0 10.0 10.0 45.0 -1.6 0.0 0.0 0.0)" | yarp rpc /ctpservice/right_arm/rpc
}

go_home()
{
    go_home_helper 5.0
}

#######################################################################################
# SEQUENCE FUNCTIONS
#######################################################################################

reset_test(){
    echo "ctpn time 4.0 off 0 pos (72.8285 19.8633 -10.0196 34.9806 0.532838 0.0298284 -0.0376696 0.195737)" | yarp rpc /ctpservice/right_arm/rpc
}

stop_test(){
    echo "ctpn time 4.0 off 0 pos (45.7581683549032 19.8633297444574 -10.0195557118059 35.0684449913208 0.0878908395772451 0.0298284026456716 -0.0376695839922819 0.195737309062505)" | yarp rpc /ctpservice/right_arm/rpc
    echo "finished"
}

start_test(){
    echo "testing interruption" 
    echo "ctpn time 4.0 off 0 pos (-21.742 20.0391 -9.93166 35.0684 0.977786 0.0298225 -0.0565045 0.163115)" | yarp rpc /ctpservice/right_arm/rpc
    echo "am I blocked?" 
}

step_all(){
    echo "step 1" 
    echo "step 1" | yarp write ... /tags
    step_1
    sleep 3.5
    echo "step 2" 
    echo "step 2" | yarp write ... /tags
    step_2
    sleep 8.5
    echo "step 3" 
    echo "step 3" | yarp write ... /tags
    step_3
    sleep 3.0
    echo "step 4" 
    echo "step 4" | yarp write ... /tags
    step_4
    sleep 7.0
    echo "step 5" 
    echo "step 5" | yarp write ... /tags
    step_5
    sleep 10.0
    echo "step 6" 
    echo "step 6" | yarp write ... /tags
    step_6
    sleep 7.0
    echo "step 7" 
    echo "step 7" | yarp write ... /tags
    step_7
    echo "done." 
}

step_start() {
    all_home
}

step_1() {
    base_backwards &
    echo "ctpq time 1.5 off 0 pos (30.0 0.0)" | yarp rpc /ctpservice/head/rpc
    torso_up_backwards
}

step_2() {
    base_forwards_far &
    torso_left_down
}

step_3() {
    echo "ctpq time 1.5 off 0 pos (36.0 0.0)" | yarp rpc /ctpservice/head/rpc 
    torso_home_down
    arms_home
}

step_4() {
    base_backwards &
    torso_up
    head_down
}

step_5() {
    base_forwards &
    torso_right_down
}

step_6() {
    torso_up_forwards
    arms_home
    echo "ctpq time 1.5 off 0 pos (31.0 0.0)" | yarp rpc /ctpservice/head/rpc
}

step_7() {
    base_backwards_adjust &
    sleep 1.0
    echo "ctpq time 1.5 off 0 pos (21.0 0.0)" | yarp rpc /ctpservice/head/rpc 
    torso_home_down
}

all_home() {
    head_down
    torso_home
    arms_home
    
}

head_down() {
     echo "ctpq time 1.5 off 0 pos (29.0 0.0)" | yarp rpc /ctpservice/head/rpc
}

arms_home() {
    echo "ctpq time 4.0 off 0 pos (-10.047 20.0391 -10.0196 34.9806 0.983279 0.0297988 0.0376698 0.0)" | yarp rpc /ctpservice/left_arm/rpc
    echo "ctpq time 4.0 off 0 pos (-10.047 20.0391 -10.0196 34.9806 0.983279 0.0297988 0.0376698 0.0)" | yarp rpc /ctpservice/right_arm/rpc
}

head_torso_forwards() {
   echo "ctpq time 1.5 off 0 pos (26.0 0.0)" | yarp rpc /ctpservice/head/rpc
}

head_base_torso_forwards() {
   echo "ctpq time 1.5 off 0 pos (39.0 0.0)" | yarp rpc /ctpservice/head/rpc
}

head_torso_backwards() {
    echo "ctpq time 1.5 off 0 pos (39.0 0.0)" | yarp rpc /ctpservice/head/rpc
}

head_torso_down_base_home() {
    echo "ctpq time 1.5 off 0 pos (29.0 0.0)" | yarp rpc /ctpservice/head/rpc
}

torso_up_forwards() {
    echo "set vels (0.015 0.015 0.015 0.0)" | yarp rpc /cer/torso/rpc:i
    echo "set poss (0.11 -19.1197 0.0 0.0)" | yarp rpc /cer/torso/rpc:i
}

torso_up_backwards() {
    echo "set vels (0.015 0.015 0.015 0.0)" | yarp rpc /cer/torso/rpc:i
    echo "set poss (0.11 15.1197 0.0 0.0)" | yarp rpc /cer/torso/rpc:i
}	

torso_up() {
   echo "set vels (0.015 0.015 0.015 0.0)" | yarp rpc /cer/torso/rpc:i
   echo "set poss (0.15 0.0 0.0 0.0)" | yarp rpc /cer/torso/rpc:i
}

torso_home() {
   head_down
   echo "set vels (0.015 0.015 0.015 0.0)" | yarp rpc /cer/torso/rpc:i
   echo "set poss (0.08 0.0 0.0 0.0)" | yarp rpc /cer/torso/rpc:i
}

torso_home_down() {
   echo "set vels (0.013 0.013 0.013 0.0)" | yarp rpc /cer/torso/rpc:i
   echo "set poss (0.025 0.0 0.0 0.0)" | yarp rpc /cer/torso/rpc:i
}

torso_right_down() {
   echo "ctpq time 4.0 off 0 pos (-10.047 39.0235 -10.0196 34.9806 0.60425 0.0299586 -0.696857 -0.032623)" | yarp rpc /ctpservice/right_arm/rpc
   echo "ctpq time 4.0 off 0 pos (-10.047 20.0391 -10.0196 34.9806 0.983279 0.0297988 0.0376698 0.0)" | yarp rpc /ctpservice/left_arm/rpc
   echo "ctpq time 1.5 off 0 pos (34.0 3.0)" | yarp rpc /ctpservice/head/rpc
   echo "set vels (0.015 0.015 0.015 0.0)" | yarp rpc /cer/torso/rpc:i
   echo "set poss (0.025 0.0 -25.0 0.0)" | yarp rpc /cer/torso/rpc:i
}

torso_left_down() {
   echo "ctpq time 4.0 off 0 pos (-10.047 39.0235 -10.0196 34.9806 0.60425 0.0299586 -0.696857 -0.032623)" | yarp rpc /ctpservice/left_arm/rpc
   echo "ctpq time 4.0 off 0 pos (-10.047 20.0391 -10.0196 34.9806 0.983279 0.0297988 0.0376698 0.0)" | yarp rpc /ctpservice/right_arm/rpc
   echo "ctpq time 1.5 off 0 pos (36.0 -11.0)" | yarp rpc /ctpservice/head/rpc
   echo "set vels (0.015 0.015 0.015 0.0)" | yarp rpc /cer/torso/rpc:i
   echo "set poss (0.035 0.0 25.0 0.0)" | yarp rpc /cer/torso/rpc:i   
}

base_forwards() {

    for i in {1..20}
    do 
        echo "set vmos (35.0 35.0)"| yarp rpc /cer/mobile_base/rpc:i
        sleep 0.05
    done
}

base_forwards_far() {

    for i in {1..40}
    do 
        echo "set vmos (35.0 35.0)"| yarp rpc /cer/mobile_base/rpc:i
        sleep 0.05
    done
}

base_backwards() {

    for i in {1..20}
    do 
        echo "set vmos (-35.0 -35.0)"| yarp rpc /cer/mobile_base/rpc:i
        sleep 0.05
    done
}

base_backwards_adjust() {

    for i in {1..20}
    do 
        echo "set vmos (-31.0 -33.0)"| yarp rpc /cer/mobile_base/rpc:i
        sleep 0.05
    done
}

down_arms() {
   speak "I am going through the corridors"
   echo "ctpq time 2.0 off 0 pos (-10.0 5.0 -6.0 45.0 -3.2 0.0 0.0 0.0)" | yarp rpc /ctpservice/left_arm/rpc
   echo "ctpq time 2.0 off 0 pos (-10.0 5.0 -6.0 45.0 -3.2 0.0 0.0 0.0)" | yarp rpc /ctpservice/right_arm/rpc
}

torso_up() {
    echo "ctpq time 4.0 off 0 pos (0.15 0.0 0.0 0.0)" | yarp rpc /ctpservice/torso/rpc
}

torso_down() {
    echo "ctpq time 4.0 off 0 pos (0.01 0.0 0.0 0.0)" | yarp rpc /ctpservice/torso/rpc
}

home_right() {
   echo "(parameters ((mode full_pose+no_torso_no_heave)) ) (target (0.366637 -0.277564 0.857717 -0.982174 -0.187205 -0.016979 1.662991))" | yarp write ... /cer_reaching-controller/right/target:i
}

home_left() {
   echo "(parameters ((mode full_pose+no_torso_no_heave)) ) (target (0.367518 0.273386 0.850667 -0.97539 -0.014684 -0.219999 1.515129))" | yarp write ... /cer_reaching-controller/left/target:i
}

point_left() {
 
    echo "(parameters ((mode full_pose+no_torso_no_heave)) ) (target (0.5 0.303386 0.750667 -0.996393 0.065846 0.053525 1.47289))" | yarp write ... /cer_reaching-controller/left/target:i    
}

point_right() {
    echo "(parameters ((mode full_pose+no_torso_no_heave)) ) (target (0.5 -0.303386 0.750667 -0.996393 0.065846 0.053525 1.47289))" | yarp write ... /cer_reaching-controller/right/target:i    
}

head_rest() {
    echo "(control-frame depth) (target-type angular) (target-location (0.0 -10.0)) " | yarp write ... /cer_gaze-controller/target:i
}

head_left() {
    echo "(control-frame depth) (target-type angular) (target-location (20.0 -20.0)) " | yarp write ... /cer_gaze-controller/target:i
}

head_right() {
    echo "(control-frame depth) (target-type angular) (target-location (-20.0 -20.0)) " | yarp write ... /cer_gaze-controller/target:i
}

close_thumb_left() {
    echo "pointing left " | yarp rpc /superquadric-grasp/rpc
}

close_thumb_right() {
    echo "pointing right" | yarp rpc /superquadric-grasp/rpc
}

open_thumb_left() {
    echo "rest left" | yarp rpc /superquadric-grasp/rpc
}

open_thumb_right() {
    echo "rest right" | yarp rpc /superquadric-grasp/rpc
}

stop() {
    echo "stop" | yarp rpc /cer_reaching-controller/left/rpc
    echo "stop" | yarp rpc /cer_reaching-controller/right/rpc
}


#######################################################################################

sequence_setup() {

    torso_up
    head_rest
    sleep 6.0
    home_left
    home_right
    
}

sequence_rest() {

    torso_down
    head_rest
    sleep 3.0
    down_arms
    
}

print() {
echo "stop"

}

sequence() {
    
 ################################################ head left   
    head_left
    sleep 2.0
########################  return  
    head_rest
    sleep 2.0
################################################  head + point left 
    head_left
    point_left
    close_thumb_left
                        sleep 4.0
    stop
    sleep 0.5
########################  return    
    home_left
    head_rest
    open_thumb_left
                        sleep 4.0
    stop
    sleep 0.5
################################################ head + point right 
    head_right
    close_thumb_right
    point_right
                        sleep 4.0
    stop
    sleep 0.5
########################  return
    home_right
    head_rest
    open_thumb_right
                        sleep 4.0
    stop
    sleep 0.5
################################################ head right
    head_right
    sleep 2.0
########################  return  
    head_rest
    sleep 2.0
################################################  point left 
    
    point_left
    close_thumb_left
                        sleep 4.0
    stop
    sleep 0.5
########################  return    
    home_left
    
    open_thumb_left
                        sleep 4.0
    stop
    sleep 0.5
################################################  point right 
    
    point_right
    close_thumb_right
                        sleep 4.0
    stop
    sleep 0.5
########################  return    
    home_right
    
    open_thumb_right
                        sleep 4.0
    stop
    sleep 0.5
}


sequence_long() {

        
    sequence
    sleep 1.0
    sequence
    
}


#######################################################################################
# "MAIN" FUNCTION:                                                                    #
#######################################################################################
echo "********************************************************************************"
echo ""

$1 "$2"

if [[ $# -eq 0 ]] ; then
    echo "No options were passed!"
    echo ""
    usage
    exit 1
fi
