public function get_calling_contact_list()
{
    if ($this->input->post('uid') != null) {

        $uid     = (int)$this->input->post('uid');
        $f_token = $this->input->post('f_token');

        // 1️⃣ Check if user exists
        $check_user = $this->Api_Model->getData('user_details', [
            'uid' => $uid,
            'user_type' => 2
        ]);

        if (!empty($check_user)) {

            $send_data = [];

            // 2️⃣ Fetch users I blocked
            $blocked_users = $this->Api_Model->getAllData('block_user', ['uid' => $uid]);
            $blocked_ids = [];

            if (!empty($blocked_users)) {
                foreach ($blocked_users as $b) {
                    $blocked_ids[] = (int)$b['blocked_uid'];
                }
            }

            // 3️⃣ Fetch my saved contacts
            $contacts = $this->Api_Model->getAllData('user_contacts', ['uid' => $uid]);

            if (!empty($contacts)) {

                foreach ($contacts as $contact) {

                    $contact_number = $contact['contact_number'];

                    // 4️⃣ Check if contact is a registered user
                    $user_data = $this->Api_Model->getData('user_details', [
                        'mobile_no' => $contact_number,
                        'user_type' => 2
                    ]);

                    if (!empty($user_data)) {

                        $friend_id = (int)$user_data['uid'];

                        // 5️⃣ Block check
                        $is_blocked = in_array($friend_id, $blocked_ids, true);

                        // 6️⃣ Mutual contact check
                        $my_saved_their_number = $this->Api_Model->getData(
                            'user_contacts',
                            '(uid="' . $uid . '" AND contact_number="' . $user_data['mobile_no'] . '")'
                        );

                        $they_saved_my_number = $this->Api_Model->getData(
                            'user_contacts',
                            '(uid="' . $friend_id . '" AND contact_number="' . $check_user['mobile_no'] . '")'
                        );

                        // 7️⃣ Photo visibility logic
                        $show_profile_photo = !empty($my_saved_their_number) && !empty($they_saved_my_number);

                        $photo = ($show_profile_photo && !empty($user_data['photo']))
                            ? base_url($user_data['photo'])
                            : base_url('assets/images/user_profile.png');

                        // 8️⃣ Display name logic
                        $full_name = !empty($contact['contact_name'])
                            ? $contact['contact_name']
                            : $user_data['mobile_no'];

                        // 9️⃣ Theme color
                        $themeColor = !empty($user_data['themeColor'])
                            ? $user_data['themeColor']
                            : '#00A3E9';

                        $send_data[] = [
                            'uid'         => $friend_id,
                            'photo'       => $photo,
                            'full_name'   => $full_name,
                            'mobile_no'   => $user_data['mobile_no'],
                            'caption'     => $user_data['caption'] ?? '',
                            'f_token'     => $user_data['f_token'] ?? '',
                            'voip_token'  => $user_data['voip_token'] ?? '', // 🆕 VoIP token for iOS CallKit

                            // ✅ device_id → device_type
                            'device_type' => isset($user_data['device_id'])
                                ? (string)$user_data['device_id']
                                : '',

                            'themeColor'  => $themeColor,
                            'block'       => $is_blocked
                        ];
                    }
                }
            }

            // 🔟 Final response
            if (!empty($send_data)) {
                $response = [
                    'success'    => "1",
                    'error_code' => "200",
                    'message'    => "Success",
                    'data'       => $send_data
                ];
            } else {
                $response = [
                    'success'    => "0",
                    'error_code' => "404",
                    'message'    => "No contacts found."
                ];
            }

        } else {
            $response = [
                'success'    => "0",
                'error_code' => "404",
                'message'    => "User not found."
            ];
        }

    } else {
        $response = [
            'success'    => "0",
            'error_code' => "406",
            'message'    => "Required Parameter Missing"
        ];
    }

    echo json_encode($response);
    exit();
}
