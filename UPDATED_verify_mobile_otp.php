public function verify_mobile_otp()
{
	
	if ($this->input->post('uid') != null && $this->input->post('mob_otp') != null && $this->input->post('f_token') != null && $this->input->post('device_id') != null &&  $this->input->post('phone_id') != null) {
		$uid = $this->input->post('uid');
		$mob_otp = $this->input->post('mob_otp');
		$f_token = $this->input->post('f_token');
		$device_id = $this->input->post('device_id');
		$phone_id = $this->input->post('phone_id');
		
		// 🆕 Get VoIP token (OPTIONAL - only iOS sends this)
		$voip_token = $this->input->post('voip_token') != null ? $this->input->post('voip_token') : '';

		$where = '(uid="' . $uid . '" AND user_type = 2)';
		$check_user = $this->Api_Model->getData($tbl = 'user_details', $where);

		if (!empty($check_user)) {
			///  1. device id empty
			if (!empty($check_user['device_id'])) {
				if ($uid == $check_user['uid']) {
					// login success
					if ($mob_otp == "101010") {
						$wh_mob = '(mobile_no="' . $check_user['mobile_no'] . '")';
						$check_otp = $this->Api_Model->getData($tbl = 'user_details', $wh_mob);
					} else {

						$wh_otp = '(mob_otp = "' . $mob_otp . '")';
						$check_otp = $this->Api_Model->getData($tbl = 'user_details', $wh_otp);
					}

					if (!empty($check_otp)) {
						if ($mob_otp == $check_otp['mob_otp'] || $mob_otp == "101010") { // || $mob_otp == "101010"
							
							// 🆕 Add voip_token to update array
							$arr = array(
								'mob_otp_verfied' => 1,
								'is_registered' => 1,
								'registration_date' => date("Y-m-d"),
								'f_token' => $f_token,
								'device_id' => $device_id,
								'phone_id' => $phone_id
							);
							
							// 🆕 Only add voip_token if it's not empty (iOS only)
							if (!empty($voip_token)) {
								$arr['voip_token'] = $voip_token;
								error_log("✅ [VOIP] iOS user login - Saving VoIP token: " . substr($voip_token, 0, 20) . "...");
							}

							$update_id = $this->Api_Model->editData($tbl = 'user_details', $where, $arr);

							if ($update_id) {
								
								// 🆕 Prepare response data
								$send_data_item = array(
									'uid' => $check_otp['uid'],
									'mobile_no' => $check_otp['mobile_no'],
									'f_token' => $f_token,
									'device_id' => $device_id,
									'phone_id' => $check_otp['phone_id']
								);
								
								// 🆕 Include voip_token in response if available
								if (!empty($voip_token)) {
									$send_data_item['voip_token'] = $voip_token;
								}
								
								$send_data[] = $send_data_item;

								$response['success']	=	"1";
								$response['error_code']	=	"200";
								$response['message']	=	"OTP Verified Successfully";
								$response['data'] = $send_data;
								echo json_encode($response);
								exit();
							} else {
								$response['success'] = "0";
								$response['error_code'] = "403";
								$response['message'] = "Something Went Wrong";
								echo json_encode($response);
								exit();
							}
						} else {
							$response['success'] = 0;
							$response['error_code'] = 201;
							$response['message'] = "Either User or OTP is incorrect";
							echo json_encode($response);
							exit();
						}
					} else {
						$response['success'] = "0";
						$response['error_code'] = "404";
						$response['message'] = "Please enter valid OTP";
						echo json_encode($response);
						exit();
					}
				} else {
					$response['success'] = 0;
					$response['error_code'] = 201;
					$response['message'] = "Already logged in another device";
					echo json_encode($response);
					exit();
				}
			} else {
				
				// 🆕 Add voip_token to update array
				$arr_edit = array(
					'mob_otp_verfied' => 1,
					'is_registered' => 1,
					'registration_date' => date("Y-m-d"),
					'f_token' => $f_token,
					'device_id' => $device_id,
					'phone_id' => $phone_id
				);
				
				// 🆕 Only add voip_token if it's not empty (iOS only)
				if (!empty($voip_token)) {
					$arr_edit['voip_token'] = $voip_token;
					error_log("✅ [VOIP] iOS user first login - Saving VoIP token: " . substr($voip_token, 0, 20) . "...");
				}
				
				$wh_1 = '(uid="' . $uid . '" AND user_type = 2)';
				$update_id = $this->Api_Model->editData($tbl = 'user_details', $wh_1, $arr_edit);
				if ($update_id) {
					$wh_2 = '(uid="' . $uid . '")';
					$check_info = $this->Api_Model->getData($tbl = 'user_details', $wh_2);

					// 🆕 Prepare response data
					$send_data_item = array(
						'uid' => $check_info['uid'],
						'mobile_no' => $check_info['mobile_no'],
						'f_token' => $check_info['f_token'],
						'device_id' => $check_info['device_id'],
						'phone_id' => $check_info['phone_id']
					);
					
					// 🆕 Include voip_token in response if available
					if (!empty($voip_token)) {
						$send_data_item['voip_token'] = $voip_token;
					}
					
					$send_data[] = $send_data_item;

					$response['success']	=	"1";
					$response['error_code']	=	"200";
					$response['message']	=	"OTP Verified Successfully";
					$response['data'] = $send_data;
					echo json_encode($response);
					exit();
				} else {
					$response['success'] = "0";
					$response['error_code'] = "403";
					$response['message'] = "Something Went Wrong";
					echo json_encode($response);
					exit();
				}
			}
		} else {
			$response['success'] = "0";
			$response['error_code'] = "404";
			$response['message'] = "User not found.";
			echo json_encode($response);
			exit();
		}
	} else {
		$response['success'] = "0";
		$response['error_code'] = "406";
		$response['message'] = "Required Parameter Missing";
		echo json_encode($response);
		exit();
	}
}
