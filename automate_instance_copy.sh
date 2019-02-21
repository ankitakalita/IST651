#!/bin/bash
#------------------------------------------------------------#
# This script creates instances automatically in openstack
# Can be run on 2 mode - interactive (-i) or configuration file (-c) mode.
# Reads the configuration details from conf.txt in -c mode
# can be created in existing network or can be craeted while creating new network
# The sample of conf.txt file is :
# <networkname>,<range>,<no_ofvms>,<falvor>,<image>,<securitygroup>,<key_name>
# ----------------------------------------------------------#
#Getting the details of the openstack environmets
#neutron net-list>network_list
#nova flavor-list>flavor_list
#nova image-list>image_list
#nova secgroup-list>secgroup_list
#nova keypair-list>keypair_list

if [ ! -z `ls |grep -x final_config.sh` ]
  then 
      rm final_config.sh
fi

#### network check function in case of new network 
network_checking()
{
#------------------------------------------------------------#
#when new and the user will defined 30 host, a network checking should be performed to chose the next available network.
#declare -i range=2050
declare -i range=$1
if [ "$range" -le 255 ]
then 
v_network_cider=`cat network_list | tr -d "[:blank:]"| cut -d'|' -f4 | cut -c37-46 | sed -e '1,3d' | sed '$d' | cut -d '.' -f1,2,3 |sort -rn|head -1`
OCT1=$(echo $v_network_cider | cut -d "." -f1)
OCT2=$(echo $v_network_cider | cut -d "." -f2)
declare -i v_OCT3
v_OCT3=$(echo $v_network_cider | cut -d "." -f3)
declare -i OCT3
declare -i OCT4=0
OCT3=$v_OCT3+1
network_cider="$OCT1.$OCT2.$OCT3.$OCT4/24"
gateway_ip="$OCT1.$OCT2.$OCT3.1"
startip="$OCT1.$OCT2.$OCT3.2"
#OCT4="$OCT4+$range"
endip="$OCT1.$OCT2.$OCT3.$range"
#echo "$network_cider"
#echo "$gateway_ip"
#echo "$startip"
#echo "$endip"
elif [ "$range" -gt 255 ] && [ "$range" -lt 65535 ]
then 
v_network_cider=`cat network_list | tr -d "[:blank:]"| cut -d'|' -f4 | cut -c37-46 | sed -e '1,3d' | sed '$d' | cut -d '.' -f1,2 |sort -rn|head -1`
OCT1=$(echo $v_network_cider | cut -d "." -f1)
declare -i v_OCT2
declare -i OCT2
declare -i OCT3=0
declare -i OCT4=0
v_OCT2=$(echo $v_network_cider | cut -d "." -f2)
OCT2=$v_OCT2+1
    if [ "$range" -gt 256 ] && [ "$range" -lt 512 ]
    then
       OCT3=1
       OCT4=$range-255
       
    elif [ "$range" -gt 513 ] && [ "$range" -lt 1024 ]
    then
       OCT3=3
       OCT4=$range-512
    
    elif [ "$range" -gt 1025 ] && [ "$range" -lt 2048 ]
    then
       OCT3=7
       OCT4=$range-1024
    
    elif [ "$range" -gt 2049 ] && [ "$range" -lt 4069 ]
    then
       OCT3=15
       OCT4=$range-2048
    
    elif [ "$range" -gt 4070 ] && [ "$range" -lt 8192 ]
    then
       OCT3=31
       OCT4=$range-4069
    
    elif [ "$range" -gt 8193 ] && [ "$range" -lt 16384 ]
    then
       OCT3=63
       OCT4=$range-8192
       
    elif [ "$range" -gt 16385 ] && [ "$range" -lt 32768 ]
    then
       OCT3=127
       OCT4=$range-16384
       
    elif [ "$range" -gt 32769 ] && [ "$range" -lt 65536 ]
    then
       OCT3=255
       OCT4=$range-32768
    fi
network_cider="$OCT1.$OCT2.0.0/16"
gateway_ip="$OCT1.$OCT2.0.1"
startip="$OCT1.$OCT2.0.2"
endip="$OCT1.$OCT2.$OCT3.$OCT4"
#echo "$network_cider"
#echo "$gateway_ip"
#echo "$startip"
#echo "$endip"
#else 
# echo "the range should be less than 65536"

fi
}

#### end of network check function in case of new network 
option=$1
#echo $option
if [ -z $option ]
then
   echo "you have not mentioned any configuration mode. Should be -i or -c . Read readme.txt"
   exit 0
elif [ $option == '-c' ]
then 
  echo "You have choose configuration file mode"
  file_name=$2
  ### checking the configuration file mentioned or present or not
  if [ -z $file_name ]
  then 
      echo "You need to mention the configuration file name in configuration file mode. Please read readme.txt for details"
      exit 0
  elif [ -z `ls |grep -x $file_name` ]
  then 
      echo "The configuration file you mentioned is not present. Mentioned a valid configuration file"
      exit 0
  fi
  ### end of checking the configuration file mentioned or present or not
  
  while read line
  do
        #echo "$line"
        var1=$line
  done < $file_name
  echo "The contant of the configuration file is:"
  echo "$var1"
  declare -i j=0
  for i in $(echo $var1 | tr ',' '\n')
  do
   var2[$j]=$i
   #echo ${var2[$j]}
   j=j+1
  done
  #echo "$j"
  ###checking correct config file structure 
  if [ $j != 8 ] #checking correct number args passed
  then
      echo "The config file does not contain correct number of parameters. Please read readme.txt for details"
      echo "Existing from the configuration"
      exit 0
  fi
  
  networkname=${var2[0]}
  range=${var2[1]}
  No_of_instances=${var2[2]}
  flavor=${var2[3]}
  image=${var2[4]}
  securitygroup=${var2[5]}
  key_name=${var2[6]}
  config_type=${var2[7]}
  
  ### checking configuration type 
  if [ $config_type != 'new' ] && [ $config_type != 'existing' ]
  then 
       echo "You have entered wrong configuration type. Should be new or existing "
       exit 0
  fi
  
  ####checking network name
  net_name_existing=`cat network_list | grep $networkname | tr -d "[:blank:]" | grep "|$networkname|" | cut -d'|' -f3`
  if [ $config_type == 'existing' ]
  then 
      if [ -z $net_name_existing ]
      then 
		 echo "The network you mentioned is not present in the environment .Choose an existing network"
		 v1_net_name_existing=`cat network_list | tr -d "[:blank:]"| cut -d'|' -f3`
		 printf "The avilable networks are :\n$v1_net_name_existing\n"
	     exit 0
       fi
  elif [ $config_type == 'new' ]
  then
      if [ ! -z $net_name_existing ]
      then 
		 echo "The network name you entered already present . Please choose a new name"
		 exit 0
      fi
   fi
  
  ###checking correct config file structure 
  if ! [[ "$No_of_instances" =~ ^[0-9]+$ ]] #checking parameter for number of vms
  then 
     echo "Number of instances should be an integer. Please read readme.txt for details"
     echo "Existing from the configuration"
     exit 0
  fi

  ###checking on flavor, new flavor is not allowded to create through this script
  #nova flavor-list>flavor_list
  v1_flavor=`cat flavor_list | grep $flavor | tr -d "[:blank:]" | grep "|$flavor|" | cut -d'|' -f3`
  #echo "$v1_flavor"
  if [ -z $v1_flavor ]
  then
       echo "The flavor you mentioned is not avilable for this environment"
       v2_flavor=`cat flavor_list`
       printf "The avilable flavor are :\n$v2_flavor\n" 
       exit 0
  fi

  ###checking on image, new image is not allowded to create through this script
  #nova image-list>image_list
  v1_image=`cat image_list | grep $image | tr -d "[:blank:]" | grep "|$image|" | cut -d'|' -f3`
  if [ -z $v1_image ]
	then
 		echo "The image you mentioned is not available for this environment"
 		v2_image=`cat image_list | tr -d "[:blank:]"| cut -d'|' -f3`
 		printf "The available images are :\n$v2_image\n" 
 		exit 0
  fi

  ###checking on security group, new security group is not allowded to create through this script
  #nova secgroup-list>secgroup_list
  v1_secgroup=`cat secgroup_list | grep $securitygroup | tr -d "[:blank:]" | grep "|$securitygroup|" | cut -d'|' -f3`
  if [ -z $v1_secgroup ]
	then
 		echo "The security group you mentioned is not available for this environment"
 		v2_secgroup=`cat secgroup_list | tr -d "[:blank:]"| cut -d'|' -f3`
 		printf "The available security group are :\n$v2_secgroup\n" 
 		exit 0
  fi

  ###checking on key pair, new key pair is not allowded to create through this script
  #nova keypair-list>keypair_list
  v1_keypair=`cat keypair_list | grep $key_name | tr -d "[:blank:]" | grep "|$key_name|" | cut -d'|' -f2`
  if [ -z $v1_keypair ]
	then
 		echo "The key you mentioned is not available for this environment"
 		v2_keypair=`cat keypair_list | tr -d "[:blank:]"| cut -d'|' -f2`
 		printf "The available keys are :\n$v2_keypair\n" 
 		exit 0
  fi

  #####checking done for conguration mode type -c
  
elif [ $option == '-i' ]
then 
     echo " you have choose interactive mode " 
     #### taking configuration type and checking whether entered correct or not
     flag='false'
     while [ $flag == 'false' ]
     do
         read -p "Enter new or existing depending on the network you want to create: " config_type
         echo $config_type
           if [ $config_type == 'new' ] || [ $config_type == 'existing' ]
           then 
               flag='true'
           else 
               echo "You have entered wrong configuration type. Should be new or existing "
           fi
     done
     #### end of taking configuration type and checking whether entered correct or not
  
     #####checking network name
     flag1='false'
     while [ $flag1 == 'false' ]
     do
         read -p "Enter the network name " networkname
         echo $networkname
         #neutron net-list>network_list
         net_name_existing=`cat network_list | grep $networkname | tr -d "[:blank:]" | grep "|$networkname|" | cut -d'|' -f3`
         if [ $config_type == 'existing' ]
         then 
             if [ -z $net_name_existing ]
             then 
		          echo "The network you mentioned is not present in the environment .Choose an existing network"
		          v1_net_name_existing=`cat network_list | tr -d "[:blank:]"| cut -d'|' -f3`
		          printf "The avilable networks are :\n$v1_net_name_existing\n"
	         else 
	              flag1='true'
             fi
        elif [ $config_type == 'new' ]
        then
            if [ -z $net_name_existing ]
            then 
		         flag1='true'
	        else
	             echo "The network name you entered already present . Please choose a new name"
            fi
        fi
     done
     #####end of checking network name
     
     #####checking flavor name
     flag2='false'
     while [ $flag2 == 'false' ]
     do
         read -p "Enter the flavor : " flavor
         echo $flavor
         v1_flavor=`cat flavor_list | grep $flavor | tr -d "[:blank:]" | grep "|$flavor|" | cut -d'|' -f3`
         echo "$v1_flavor"
         if [ -z $v1_flavor ]
         then
              echo "The flavor you mentioned is not avilable for this environment"
              v2_flavor=`cat flavor_list`
              printf "The avilable flavor are :\n$v2_flavor\n" 
         else
              flag2='true'            
         fi
     done
     #####end of checking flavor name
     
    #####checking image
     flag3='false'
     while [ $flag3 == 'false' ]
     do
         read -p "Enter the image : " image
         echo $image
         v1_image=`cat image_list | grep $image | tr -d "[:blank:]" | grep "|$image|" | cut -d'|' -f3`
         if [ -z $v1_image ]
	     then
 		      echo "The image you mentioned is not available for this environment"
 			  v2_image=`cat image_list | tr -d "[:blank:]"| cut -d'|' -f3`
 			  printf "The available images are :\n$v2_image\n" 
 		 else
 		      flag3='true'
         fi
     done
     #####end of checking image name
     #####checking security group
     flag4='false'
     while [ $flag4 == 'false' ]
     do
         read -p "Enter the security group : " securitygroup
         echo $securitygroup
         v1_secgroup=`cat secgroup_list | grep $securitygroup | tr -d "[:blank:]" | grep "|$securitygroup|" | cut -d'|' -f3`
         if [ -z $v1_secgroup ]
	     then
 	     	echo "The security group you mentioned is not available for this environment"
 			v2_secgroup=`cat secgroup_list | tr -d "[:blank:]"| cut -d'|' -f3`
 			printf "The available security group are :\n$v2_secgroup\n" 
 		 else 
 		    flag4='true'
         fi
     done
     #####end of checking security group 
     #####checking key 
     flag5='false'
     while [ $flag5 == 'false' ]
     do
         read -p "Enter the key : " key_name
         echo $key_name
         v1_keypair=`cat keypair_list | grep $key_name | tr -d "[:blank:]" | grep "|$key_name|" | cut -d'|' -f2`
         if [ -z $v1_keypair ]
	     then
 		    echo "The key you mentioned is not available for this environment"
 			v2_keypair=`cat keypair_list | tr -d "[:blank:]"| cut -d'|' -f2`
 			printf "The available keys are :\n$v2_keypair\n" 
 		 else
 		    flag5='true'
         fi
     done
     #####end of checking security group 
     #### checking number of instances
     flag6='false'
     while [ $flag6 == 'false' ]
     do
         read -p "Enter number of instance you want to create : " No_of_instances
         echo $No_of_instances
         if ! [[ "$No_of_instances" =~ ^[0-9]+$ ]] #checking parameter for number of vms
         then 
           echo "Number of instances should be an integer."
         else
            flag6='true'
         fi
     done
     #### checking size of subnet
     flag7='false'
     while [ $flag7 == 'false' ]
     do
         if [ $config_type == 'new' ]
         then
            read -p "Enter size of the subnet you want to create : " range
            echo $range
            if ! [[ "$range" =~ ^[0-9]+$ ]] #checking parameter for subnet
            then 
               echo "range of the subnet should be an integer."
            else
               flag7='true'
            fi
         else 
            flag7='true'
         fi
     done  
else
   echo "you have mentioned wrong configuration mode. Should be -i or -c . Read readme.txt"
   exit 0
fi
#echo $config_type
######creating final configuration file
if [ $config_type == 'new' ]
then
		network_checking $range
		cat check_status.txt>>final_config.sh
		echo "#this is a configuration in $config_type network">>final_config.sh
		echo "#neutron net-create $networkname">>final_config.sh
		echo "check_status \$?">>final_config.sh
		echo "#neutron subnet-create --name ${networkname}_subnet --gateway $gateway_ip ${networkname} $network_cider --allocation-pool start=$startip,end=$endip">>final_config.sh
		echo "check_status \$?">>final_config.sh
		echo "#neutron router-create ${networkname}_router">>final_config.sh
		echo "check_status \$?">>final_config.sh
		echo "#neutron router-gateway-set ${networkname}_router ext-net">>final_config.sh
		echo "check_status \$?">>final_config.sh
		echo "#neutron router-interface-add ${networkname}_router ${networkname}_subnet">>final_config.sh
		echo "check_status \$?">>final_config.sh
		#neutron net-list>network_list
		netid=`cat network_list1 | grep $networkname | tr -d "[:blank:]" | grep "|$networkname|" | cut -d'|' -f2`

		for ((k=1;k<=${No_of_instances};k++))
		do
  			v_date=`date "+%Y%m%d%H%M%S"`
  			sleep 1
  			echo "#nova boot --flavor ${flavor} --image ${image} --security-group ${securitygroup} --key-name ${key_name} --nic net-id=$netid PC_$v_date">>final_config.sh
		    echo "check_status \$?">>final_config.sh
		done
		echo "echo \"The configuration completed successfully\"">>final_config.sh
elif [ $config_type == 'existing' ]
then
		cat check_status.txt>>final_config.sh
		echo "#this is a configuration in $config_type network">>final_config.sh
		netid=`cat network_list | grep $networkname | tr -d "[:blank:]" | grep "|$networkname|" | cut -d'|' -f2`
		for ((k=1;k<=${No_of_instances};k++))
		do
  			v_date=`date "+%Y%m%d%H%M%S"`
  			sleep 1
  			echo "#nova boot --flavor ${flavor} --image ${image} --security-group ${securitygroup} --key-name ${key_name} --nic net-id=$netid PC_$v_date">>final_config.sh
		    echo "check_status \$?">>final_config.sh
		done
		echo "echo \"The configuration completed successfully\"">>final_config.sh
fi
chmod 777 final_config.sh
v_logdate=`date "+%Y%m%d%H%M%S"`
./final_config.sh #> log_$v_logdate 2>&1
date
echo " after the execution"