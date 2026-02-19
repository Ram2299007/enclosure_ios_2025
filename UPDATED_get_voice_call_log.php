public function get_voice_call_log()
{
    if ($this->input->post('uid') != null) {

        $uid     = (int)$this->input->post('uid');
        $f_token = $this->input->post('f_token');

        // 1️⃣ Fetch blocked users
        $blocked_users = $this->Api_Model->getAllData('block_user', ['uid' => $uid]);
        $blocked_ids = [];

        if (!empty($blocked_users)) {
            foreach ($blocked_users as $b) {
                $blocked_ids[] = (int)$b['blocked_uid'];
            }
        }

        // 2️⃣ Check user
        $check_user = $this->Api_Model->getData('user_details', [
            'uid' => $uid,
            'user_type' => 2
        ]);

        if (!empty($check_user)) {

            $send_data = [];
            $get_dates = $this->Api_Model->getCallingDetails('calling_details', $uid);

            if (!empty($get_dates)) {
                $get_dates = array_slice($get_dates, 0, 14);
            }

            if (!empty($get_dates)) {

                $i = 1;
                foreach ($get_dates as $g) {

                    $user_info = [];
                    $date = $g['date'];

                    $wh_1 = '(uid="' . $uid . '" AND date="' . $date . '" AND flag = 1 AND call_type = 1)';
                    $list_1 = $this->Api_Model
                        ->getAllData_as_group_order(
                            'calling_details',
                            $wh_1,
                            'friend_id',
                            'id desc'
                        );

                    foreach ($list_1 as $l_1) {

                        $friend_id = (int)$l_1['friend_id'];

                        // 3️⃣ Block check
                        $is_blocked = in_array($friend_id, $blocked_ids, true);

                        // 4️⃣ Fetch friend user
                        $user = $this->Api_Model->getData('user_details', [
                            'uid' => $friend_id
                        ]);

                        $full_name     = '';
                        $u_f_token     = '';
                        $u_voip_token  = ''; // 🆕 Initialize VoIP token
                        $u_mobile_no   = '';
                        $photo         = base_url('assets/images/user_profile.png');

                        // ✅ device_id → device_type
                        $u_device_type = '';

                        if (!empty($user)) {

                            $u_f_token     = $user['f_token'] ?? '';
                            $u_voip_token  = $user['voip_token'] ?? ''; // 🆕 Get VoIP token
                            $u_mobile_no   = $user['mobile_no'] ?? '';
                            $u_device_type = isset($user['device_id'])
                                ? (string)$user['device_id']
                                : '';

                            // Mutual contact check
                            $my_saved_their_number = $this->Api_Model->getData(
                                'user_contacts',
                                '(uid="' . $uid . '" AND contact_number="' . $user['mobile_no'] . '")'
                            );

                            $they_saved_my_number = $this->Api_Model->getData(
                                'user_contacts',
                                '(uid="' . $friend_id . '" AND contact_number="' . $check_user['mobile_no'] . '")'
                            );

                            $show_profile_photo = !empty($my_saved_their_number) && !empty($they_saved_my_number);

                            $photo = ($show_profile_photo && !empty($user['photo']))
                                ? base_url($user['photo'])
                                : base_url('assets/images/user_profile.png');

                            $full_name = !empty($my_saved_their_number)
                                ? $my_saved_their_number['contact_name']
                                : $user['mobile_no'];
                        }

                        // 5️⃣ Last call
                        $last_cal = $this->Api_Model->getSingleLimitData(
                            'calling_details',
                            '(uid="' . $uid . '" AND friend_id="' . $friend_id . '" 
                              AND flag = 1 AND date="' . $date . '" AND call_type = 1)',
                            'id desc'
                        );

                        // 6️⃣ Call history
                        $call_history = [];
                        $check_call_log = $this->Api_Model->getAllData_as_per_order(
                            'calling_details',
                            '(uid="' . $uid . '" AND friend_id="' . $friend_id . '" 
                              AND date="' . $date . '" AND flag = 1 AND call_type = 1)',
                            'id desc'
                        );

                        foreach ($check_call_log as $li) {
                            $call_history[] = [
                                'id' => $li['id'],
                                'uid' => $li['uid'],
                                'friend_id' => $li['friend_id'],
                                'date' => date("Y-m-d", strtotime($li['date'])),
                                'start_time' => $li['start_time'],
                                'end_time' => $li['end_time'],
                                'calling_flag' => $li['calling_flag'],
                                'call_type' => $li['call_type']
                            ];
                        }

                        if (!empty($last_cal)) {
                            $user_info[] = [
                                'id' => $l_1['id'],
                                'last_id' => $last_cal[0]['id'],
                                'friend_id' => $friend_id,
                                'photo' => $photo,
                                'full_name' => $full_name,
                                'f_token' => $u_f_token,
                                'voip_token' => $u_voip_token, // 🆕 Add VoIP token to response

                                // ✅ FINAL device_type
                                'device_type' => $u_device_type,

                                'mobile_no' => $u_mobile_no,
                                'date' => date("Y-m-d", strtotime($last_cal[0]['date'])),
                                'start_time' => $last_cal[0]['start_time'],
                                'end_time' => $last_cal[0]['end_time'],
                                'calling_flag' => $last_cal[0]['calling_flag'],
                                'call_type' => $last_cal[0]['call_type'],
                                'call_history' => $call_history,
                                'block' => $is_blocked,
                                'themeColor' => $user['themeColor'] ?? '#00A3E9'
                            ];
                        }
                    }

                    if (!empty($user_info)) {
                        $send_data[] = [
                            'date' => $date,
                            'sr_nos' => $i++,
                            'user_info' => $user_info
                        ];
                    }
                }
            }

            $response = [
                'success' => "1",
                'error_code' => "200",
                'message' => "Success",
                'data' => $send_data
            ];

        } else {
            $response = [
                'success' => "0",
                'error_code' => "404",
                'message' => "User not found."
            ];
        }

    } else {
        $response = [
            'success' => "0",
            'error_code' => "406",
            'message' => "Required Parameter Missing"
        ];
    }

    echo json_encode($response);
    exit();
}
