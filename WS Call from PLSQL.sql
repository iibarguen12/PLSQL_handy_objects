--AS SYSDBA:
--Create the user that will send the requests
create user C##WEB_SERVICE identified by "wspassword";

--Grant the privileges to excecute http, lock managment service and connect to the DB
grant execute on utl_http to C##WEB_SERVICE;
grant execute on dbms_lock to C##WEB_SERVICE;
grant connect to C##WEB_SERVICE;

--Create the Access Control List and associated with the user C##WEB_SERVICE with the privileges of connect
BEGIN
  DBMS_NETWORK_ACL_ADMIN.create_acl (
    acl          => 'local_acl_file.xml', 
    description  => 'ACL functionality for Web Service Calls',
    principal    => 'C##WEB_SERVICE',
    is_grant     => TRUE, 
    privilege    => 'connect',
    start_date   => SYSTIMESTAMP,
    end_date     => NULL);
end;
/
--Configured the host to be accessed by the port 8000 and above
begin
  DBMS_NETWORK_ACL_ADMIN.assign_acl (
    acl         => 'local_acl_file.xml',
    host        => 'localhost', 
    lower_port  => 8000,
    upper_port  => NULL);    
end;
/
commit;

--Create the package to wrapp the objects for the WS
create or replace package web_service as
    procedure send_request(p_url            in varchar2, 
                           p_content_type   in varchar2, 
                           p_http_method    in varchar2, 
                           p_content        in clob,                           
                           p_out_message    in out nocopy varchar2);
    
    procedure test_web_service;                        
end web_service;
/
create or replace package body web_service as
    procedure send_request(p_url            in varchar2, 
                           p_content_type   in varchar2, 
                           p_http_method    in varchar2, 
                           p_content        in clob,                           
                           p_out_message    in out nocopy varchar2)
        is
        l_request       utl_http.req;
        l_response      utl_http.resp;
        l_http_method   varchar2(100);
        l_buffer        varchar(32766);
        l_max_varhar2   number(12) := 32766;
    begin        
        --validate the passed method        
        l_http_method := upper(p_http_method);        
        if ( l_http_method not in ('POST', 'GET', 'PUT', 'PATCH', 'DELETE')) then
            p_out_message := 'HTTP method not allowed';
            RETURN;
        end if;
                
        --Initialize the request and set the parameters
        l_request := utl_http.begin_request(p_url, l_http_method,'HTTP/1.1');
        utl_http.set_header(l_request, 'user-agent', 'mozilla/4.0');
        utl_http.set_header(l_request, 'content-type', p_content_type);
        utl_http.set_header(l_request, 'Content-Length', length(p_content));
                
        --Write the content of the request
        utl_http.write_text(l_request, p_content);
                
        --Send and get the response via HTTP call
        l_response := utl_http.get_response(l_request);
                
        --Print the information from the response
        dbms_output.put_line('Response-> status code:'||l_response.status_code);
        dbms_output.put_line('Response-> reason phrase:'||l_response.reason_phrase);
                
        --Initialize the CLOB to store the response text
        p_out_message := ' ';
                
        --Process the response from the HTTP call and save it in the CLOB variable
        begin
            loop                
                utl_http.read_text(l_response, l_buffer, l_max_varhar2);                  
                dbms_lob.writeappend(p_out_message, length(l_buffer), l_buffer);
            end loop;
            utl_http.end_response(l_response);
        exception
            when utl_http.end_of_body then
                utl_http.end_response(l_response);
        end;                
    exception
        when others then
            p_out_message := 'Error in send_request procedure:'||SQLCODE||' '||SQLERRM;
    end send_request;
    
    procedure test_web_service
        is
        l_result    clob;
    begin
        dbms_output.put_line('Starting test_web_service');
        send_request(p_url            => 'http://jsonplaceholder.typicode.com/users/1',
                     p_content_type   => 'application/json',
                     p_http_method    => 'GET',
                     p_content        => '{}',
                     p_out_message    => l_result);
        
        dbms_output.put_line(substr(l_result,0,2000));
        dbms_output.put_line('End of test_web_service');
    end test_web_service;
    
end web_service;
/

--Create a public synonym for the package
create or replace public synonym ws for web_service;

--Grant the privileges to the user C##WEB_SERVICE on the synonym
grant execute on ws to C##WEB_SERVICE;

--Connect with the user C##WEB_SERVICE
--Set the server output
set serveroutput on;

--Test the package and watch the results
execute web_service.test_web_service;

--The result should be:
/*
Starting test_web_service
Response-> status code:200
Response-> reason phrase:OK
 {
  "id": 1,
  "name": "Leanne Graham",
  "username": "Bret",
  "email": "Sincere@april.biz",
  "address": {
    "street": "Kulas Light",
    "suite": "Apt. 556",
    "city": "Gwenborough",
    "zipcode": "92998-3874",
    "geo": {
      "lat": "-37.3159",
      "lng": "81.1496"
    }
  },
  "phone": "1-770-736-8031 x56442",
  "website": "hildegard.org",
  "company": {
    "name": "Romaguera-Crona",
    "catchPhrase": "Multi-layered client-server neural-net",
    "bs": "harness real-time e-markets"
  }
}
End of test_web_service

*/
