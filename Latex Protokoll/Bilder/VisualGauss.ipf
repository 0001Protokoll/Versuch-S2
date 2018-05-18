                       #pragma rtGlobals=1		// Use modern global access method.


Macro Visual_Gauss()
	PauseUpdate; Silent 1		// building window...
	string comment_string1 = "Gauss:\t\tFWHM\rLorentz:\tgamma\refunc:\t\tk"
	NewPanel /W=(90,100,400,400) as "Visual Gauss"
	SetDrawLayer UserBack
	DrawText 225,15,"Roman 2003"
	Button StartButton,pos={170,250},size={90,20}, proc=Do_Convolution, title="Convolve"
	Button CancelButton,pos={30,250},size={90,20}, proc=Cancel_Visual_Gauss, title="Quit"
	TitleBox comment_Box, disable=0, frame=3, title=comment_string1,pos={180,130},size={250,100}
	TitleBox comment_Box2, disable=0, frame=3, title="Comments go here",pos={30,200},size={250,100}
	PopupMenu w_List,pos={30,60},size={110,20}//,title="Select Wave"
	PopupMenu w_List,mode=1,popvalue="SOURCE WAVE", value= WaveList("*", ";","")
	PopupMenu function_List, pos = {30,100}, size = {200,20}//, title="Function"
	PopupMenu function_List, value = "Gaussian;Lorentzian;Exponential", mode =1,popvalue="CONVOLVE WITH..."
	SetVariable FWHM_select,pos={30, 150},size={120,15},title="Set Width",value = K0
EndMacro


 function Cancel_Visual_Gauss (CancelButton): ButtonControl
		string CancelButton	
	string panel_Name
	panel_Name = WinName(0,64)		//	64 = panel window
	DoWindow/K $panel_Name
	DoUpdate
end

 Function Do_Convolution (StartButton) : ButtonControl
	string		StartButton	
	string		info_str
	variable FWHM
	variable sigma
	string w_string, func_string
	string LC_comment_string, GC_comment_string, EXPC_comment_string
	string/G w_str = "unknown"	// fuer der den Namen der erzeugten Wave
	ControlInfo FWHM_select
	FWHM = V_value
	sigma = FWHM / (2 * sqrt ( 2 * ln(2)))
	ControlInfo w_List
	w_string = S_value
	ControlInfo function_List
	func_String = S_value
	wave w = $w_string
	strswitch(func_String)	// string switch
		case "Lorentzian":		// execute if case matches expression
			printf "Lorentzian Convolution, gamma = %g\r", FWHM
			LC(w,FWHM)			
		break
		case "Gaussian":		// execute if case matches expression
			printf "Gaussian Convolution, FWHM = %g\r", FWHM
			GC(w,FWHM,0) //Siehe Kommentar unten
		break						// exit from switch

		case "Exponential":
			EXPC(w,FWHM)
		break
		default:							// optional default expression executed
			DoAlert 0, "Please select function"						// when no case matches
	endswitch
	sprintf info_str, "Destination Wave: %s", w_str
	TitleBox comment_Box2, disable=0, frame=3, title=info_str,pos={30,200},size={250,100}

end



//*****************************************************************************
//*****************************************************************************
//*****************************************************************************
//*****************												**********************
//						die eigentlichen Konversionsroutinen
//****************												**********************
//*****************************************************************************
//*****************************************************************************


//*****************************************************************************
//*****************************************************************************
//*************************     G A U S S					***********************
//*****************************************************************************
//*****************************************************************************

function GC(w,FWHM,is_in_fitfunc)		//Gauss-Convolve
	wave w
	variable FWHM
	variable is_in_fitfunc 		// bool: 0 setzen wenn "stand-alone", 1 setzen wenn in fit-func verwendet.

	//Get several data
	SVAR/Z w_str	// fuer der den Namen der erzeugten Wave
	variable sigma = FWHM / (2 * sqrt ( 2 * ln(2)))	//this is how FWHM is defined...
	variable w_numpnts = numpnts(w)
	variable res_factor = round(deltax(w) / sigma)
	variable test

	string orig_wave_name = nameofwave(w)
	string dest_wave_name = orig_wave_name + "_GC"		//Get destination wave name
	string aux_wave_name = ""
	test = (sigma <= deltax(w))			//		Is sigma smaller than deltax(w)?? If so, we have to
	//		interpolate the source data!

	if (!is_in_fitfunc)
		printf "Gauss Convolve:\tsourcewave = %s\t,sigma = %g\r",orig_wave_name, sigma
	endif
	switch(test)	
		case 0:		// everything ok
			duplicate/o w $dest_wave_name, gwave					
			wave w_out = $dest_wave_name
			break						// exit from switch
		case 1:		// sigma too small ---> must increase number of points in wave
			if (!is_in_fitfunc)
				printf "Sigma (%g) is smaller than the source wave's (%s) increment (%g)\r", sigma, nameofwave(w), deltax(w)
				printf "We have to interpolate data from %d to %d points\r", numpnts(w), round(res_factor * numpnts(w))
			endif
			aux_wave_name = orig_wave_name + "_L"
			string interp_cmd	//the string to be executed
			sprintf interp_cmd, "Interpolate/T=1/N=(round(%g*%g) )/Y=%s %s", w_numpnts, res_factor, aux_wave_name, orig_wave_name
			execute interp_cmd
			duplicate/o $aux_wave_name $dest_wave_name, gwave
			killwaves $aux_wave_name
			break
		default:							// optional default expression executed
			printf "Sigma Comparison error occured --- EXIT_TO_SHELL\r"						// when no case matches
			return 2
	endswitch


//printf "Name of convolved wave: \t\t%s\r", dest_wave_name
	//Calculate Parameters before Convolution
	if (!is_in_fitfunc)
		printf "Area **before** convolution -->\t\t\t%g\r", area (w,leftx(w),rightx(w))
	endif
	//Define Gaussian Wave
	variable center = ((rightx($dest_wave_name)-leftx($dest_wave_name))/2 )	//Gaussian must be szmmetrical around the center of the x range
	gwave = deltax($dest_wave_name) * (1/sigma) * (1/sqrt(2 * pi)) * exp( - ((x - center - leftx($dest_wave_name))^2) / (2*sigma^2))


	//Do the convolution, but do it with the duplicated wave, **NOT** the orig one
	wave w_out = $dest_wave_name			
	convolve/a gwave,w_out

	if (test == 1)	//Interpolation auf alte Punktzahl der origwave w
		aux_wave_name = orig_wave_name + "_L1"
		string interp_cmd1
		sprintf interp_cmd1, "Interpolate/T=1/N=(numpnts(%s)) / Y=%s %s", orig_wave_name, aux_wave_name, dest_wave_name
		execute interp_cmd1
		duplicate/o $aux_wave_name $dest_wave_name
	endif
	


	// make sure the area is unchanged
	if (!is_in_fitfunc)
		printf "Area **after**  convolution -->\t\t\t%g\r", area($dest_wave_name,leftx($dest_wave_name),rightx($dest_wave_name)) 
		printf "Finished - Name of Convolved Wave:\t\t\t\t%s\r", NameofWave($dest_wave_name)
	endif
	killwaves gwave
	strswitch(aux_wave_name)	// string switch
		case "":		// execute if case matches expression
			break						// exit from switch
		
		default:							// optional default expression executed
			wave wref = $aux_wave_name
			killwaves wref			//...which is no longer needed	endswitch

	endswitch
	if (is_in_fitfunc)
		w = w_out
		killwaves w_out
	endif
	if (SVAR_exists(w_str))
		w_str = dest_wave_name
	endif
end





//*****************************************************************************
//*****************************************************************************
//	†berfaltung mit exp-Funktion
//*****************************************************************************
//*****************************************************************************

function EXPC(w,kk)
	wave w						//	Wave to be convolved ("convoluted")
	variable kk				//	Exponential Parameter in e-function

	//	Are the data consistent? ...
	SVAR 		w_str
	variable 	w_numpnts = numpnts(w)
	variable 	res_factor = round(deltax(w) / kk)
	variable 	test

	string orig_wave_name = nameofwave(w)
	string dest_wave_name = orig_wave_name + "_EC"		//Get destination wave name, _EC = exponentially convolved
	string aux_wave_name = ""
	test = (kk <= deltax(w))			//		Is kk smaller than deltax(w)?? If so, we have to
	//		interpolate the source data!

	printf "Exponential Convolution:\tsourcewave = %s\t, exp. factor = %g\r",orig_wave_name, kk

	switch(test)	
		case 0:		// everything ok
			duplicate/o w $dest_wave_name, ewave					
			wave w_out = $dest_wave_name
			break						// exit from switch
		case 1:		// kk too small ---> must increase number of points in wave
			printf "kk (%g) is smaller than the source wave's (%s) increment (%g)\r", kk, nameofwave(w), deltax(w)
			printf "We have to interpolate data from %d to %d points\r", numpnts(w), round(res_factor * numpnts(w))
			aux_wave_name = orig_wave_name + "_L"
			string interp_cmd	//the string to be executed
			sprintf interp_cmd, "Interpolate/T=1/N=(round(%g*%g) )/Y=%s %s", w_numpnts, res_factor, aux_wave_name, orig_wave_name
			execute interp_cmd
			duplicate/o $aux_wave_name $dest_wave_name, gwave
			killwaves $aux_wave_name
			break
		default:							// optional default expression executed
			DoAlert 0,"kk Comparison error occured --- EXIT_TO_SHELL"						// when no case matches
			return 2
	endswitch

	//Calculate Parameters before Convolution
	printf "Area **before** convolution -->\t\t\t%g\r", area (w,leftx(w),rightx(w))
	//Define Gaussian Wave
	//variable center = ((rightx(w)-leftx(w))/2 )		//Gaussian must be symmetrical around the center of the x range
	ewave = deltax(w) * kk * exp(-kk * (x - leftx(w)))


	//Do the convolution, but do it with the duplicated wave, **NOT** the orig one
	wave w_out = $dest_wave_name			
	convolve ewave,w_out

	if (test == 1)	//Interpolation auf alte Punktzahl der origwave w
		aux_wave_name = orig_wave_name + "_L1"
		string interp_cmd1
		sprintf interp_cmd1, "Interpolate/T=1/N=(numpnts(%s)) / Y=%s %s", orig_wave_name, aux_wave_name, dest_wave_name
		execute interp_cmd1
		duplicate/o $aux_wave_name $dest_wave_name
	endif
	


	//Just make sure the area is unchanged
	printf "Area **after**  convolution -->\t\t\t%g\r", area($dest_wave_name,leftx($dest_wave_name),rightx($dest_wave_name)) 
	printf "Finished - Name of Convolved Wave:\t\t\t\t%s\r", NameofWave($dest_wave_name)
//killwaves gwave
	strswitch(aux_wave_name)	// string switch
		case "":		// execute if case matches expression
			break						// exit from switch
		
		default:							// optional default expression executed
			wave wref = $aux_wave_name
			killwaves wref			//...which is no longer needed	endswitch

	endswitch
	if (SVAR_exists(w_str))
		w_str = dest_wave_name
	endif
end



//*****************************************************************************
//*****************************************************************************
// Lorentz
//*****************************************************************************
//*****************************************************************************

function LC(w,gamma)
	wave w
	variable gamma

	//Get several data
//variable gamma = FWHM / (2 * sqrt ( 2 * ln(2)))	//this is how FWHM is defined...
	SVAR/Z w_str	// fuer der den Namen der erzeugten Wave
	variable w_numpnts = numpnts(w)
	variable res_factor = round(deltax(w) / gamma)
	variable test

	string orig_wave_name = nameofwave(w)
	string dest_wave_name = orig_wave_name + "_LC"		//Get destination wave name
	string aux_wave_name = ""
	test = (gamma <= deltax(w))			//		Is gamma smaller than deltax(w)?? If so, we have to
	//		interpolate the source data!

	printf "Lorentz Convolve:\tsourcewave = %s\t,gamma = %g\r",orig_wave_name, gamma

	switch(test)	
		case 0:		// everything ok
			duplicate/o w $dest_wave_name, gwave					
			wave w_out = $dest_wave_name
			break						// exit from switch
		case 1:		// gamma too small ---> must increase number of points in wave
			printf "gamma (%g) is smaller than the source wave's (%s) increment (%g)\r", gamma, nameofwave(w), deltax(w)
			printf "We have to interpolate data from %d to %d points\r", numpnts(w), round(res_factor * numpnts(w))
			aux_wave_name = orig_wave_name + "_L"
			string interp_cmd	//the string to be executed
			sprintf interp_cmd, "Interpolate/T=1/N=(round(%g*%g) )/Y=%s %s", w_numpnts, res_factor, aux_wave_name, orig_wave_name
			execute interp_cmd
			duplicate/o $aux_wave_name $dest_wave_name, gwave
			killwaves $aux_wave_name
			break
		default:							// optional default expression executed
			printf "gamma Comparison error occured --- EXIT_TO_SHELL\r"						// when no case matches
			return 2
	endswitch


//printf "Name of convolved wave: \t\t%s\r", dest_wave_name
	//Calculate Parameters before Convolution
	printf "Area **before** convolution -->\t\t\t%g\r", area (w,leftx(w),rightx(w))
	//Define Gaussian Wave
	variable center = ((rightx($dest_wave_name)-leftx($dest_wave_name))/2 )	//Gaussian must be szmmetrical around the center of the x range
	gwave = deltax(w) * (2 / (pi * gamma)) * (gamma/2)^2 / (((x - center - leftx($dest_wave_name))^2) + ( (gamma/2)^2))


	//Do the convolution, but do it with the duplicated wave, **NOT** the orig one
	wave w_out = $dest_wave_name			
	convolve/a gwave,w_out

	if (test == 1)	//Interpolation auf alte Punktzahl der origwave w
		aux_wave_name = orig_wave_name + "_L1"
		string interp_cmd1
		sprintf interp_cmd1, "Interpolate/T=1/N=(numpnts(%s)) / Y=%s %s", orig_wave_name, aux_wave_name, dest_wave_name
		execute interp_cmd1
		duplicate/o $aux_wave_name $dest_wave_name
	endif
	


	//Just make sure the area is unchanged
	printf "Area **after**  convolution -->\t\t\t%g\r", area($dest_wave_name,leftx($dest_wave_name),rightx($dest_wave_name)) 
	printf "Finished - Name of Convolved Wave:\t\t\t\t%s\r", NameofWave($dest_wave_name)
//killwaves gwave
	strswitch(aux_wave_name)	// string switch
		case "":		// execute if case matches expression
			break						// exit from switch
		
		default:							// optional default expression executed
			wave wref = $aux_wave_name
			killwaves wref			//...which is no longer needed	endswitch

	endswitch
	if (SVAR_exists(w_str))
		w_str = dest_wave_name
	endif
end
