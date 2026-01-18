# Wa
Koha Plugin to Send Notices to an Endpoint which can inturn send them via Whatsapp or any other service

Idea
Set Sender as Wa

Configure an Endpoint & API Key

Koha will send notices to the Endpoint and also post json data as follows to the endpoint


		{
                "api_key"        => $api_key,
                "customerFirstName" => $patron->firstname,
                "customerLastName"  => $patron->surname,
                "phone"             => $patron->smsalertnumber || $patron->phone,
                "code"              => $m->letter_code,
                "messageBody"       => $m->content,
		}


manage the Endpoint to send Notices to whatever service you need.
