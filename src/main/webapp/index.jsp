<%@ page contentType="text/html; charset=UTF-8" %>
<%@ taglib prefix="s" uri="/struts-tags" %>
<html>
<head>
    <title>Demo</title>
</head>

<body>
<h3>Demo</h3>
<s:form action="UserName" namespace="/">
	<s:textfield name="userName" label="Your name" />
	<s:submit value="Submit" />
</s:form>
</body>
</html>
