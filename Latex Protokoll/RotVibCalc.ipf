#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=1		// Use modern global access method.

static	constant	kSpeedOfLight = 2.99792458e8						//Lichtgeschw in vacuo m*s^-1
static	constant	kPlanck = 6.6260755e-34						//Planck, J*s
static	constant 	kBoltzmann = 1.380658e-23					//Boltzmann J*K^{-1}


macro Rotvib(): Graph
	string/G winNameStr = uniquename("RotVib",6,0)
	variable/G kWeStart, kWeXeStart, kBStart, kTTStart
	Display /W=(50,50,600,600)
	Dowindow /C $winNameStr
	controlbar 100
	Button cancelRotVibButton,pos={400,30},size={50,20},proc=DoRotVibCancelPanel,title="Ende"
	Button StartButton,pos={400,10},size={90,20}, proc=DoCalculation, title="Berechnen"

	SetVariable we_select,pos={50, 10},size={200,15},title="Schwingungskonst.",value = kWeStart	
	SetVariable wexe_select,pos={50, 30},size={200,15},title="Anharm. Konst.",value = kWeXeStart
	SetVariable B_select,pos={250, 10},size={120,15},title="Rot.-Konst.",value = kBStart
	SetVariable T_select,pos={250, 30},size={120,15},title="Abs. Temp.",value = kTTStart		


end






function DoRotVibCancelPanel(cancelRotVibButton):ButtonControl
	string cancelRotVibButton
	svar winNameStr = winNameStr
	DoWindow /K $winNameStr
end





 Function DoCalculation (cancelRotVibButton) : ButtonControl
	string		cancelRotVibButton	
	variable we, wexe, B, TT

	ControlInfo we_select
	we = V_value

	ControlInfo wexe_select
	wexe = V_Value

	ControlInfo B_select
	B = V_Value

	ControlInfo T_select
	TT = V_Value
	
	
	calculatePPositions(we, wexe, B, TT)
	calculateRPositions(we, wexe, B, TT)
	ZweiInEins(pw,rw,ypw,yrw)
	NVAR minValue = gMinValue
	NVAR maxValue = gMaxValue
	minValue -= 0.2*minValue
	maxValue += 0.2*maxValue 
	LinesToSpecRotVib(XPRW,YPRW,minValue,maxValue)
	
	// €rgerlich aber notwendig: entferne die Wave YPRW_lin, falls schon vorhanden.
	String TraceString=TraceNameList("",";",1)
	variable ListItems=ItemsInList(TraceString)
	variable j
	string theTrace
	for(j=0;j<ListItems;j+=1)
		removefromgraph/Z  $(StringFromList(j,TraceString))
	endfor
	appendtograph YPRW_lin
	ModifyGraph grid=1,mirror=1,minor=1
	Label bottom "Wellenzahl [cm\\S-1\\M]"
	Label left "rel. Intensitaet [willk. Einh.]"

	ModifyGraph noLabel(left)=1
	ModifyGraph tick(left)=3
end







function calculatePPositions(we, wexe, B, TT) // P-Zweig : J -> J-1, erstes sinnvolles J'' = 1
	variable we, wexe, B, TT
	variable J, temp, yptemp
	variable nu_0 = we - 2 * wexe
	make/o/N=100 pw	// Positionen
	duplicate/o pw ypw	// Intensitaeten

	for (J=1; J<101; J+=1)
		temp =  nu_0 - 2 * B * J
		pw[J] = temp
		yptemp = (2*J) * exp( -(100*B)*(J)*(J+1) *kPlanck * kSpeedOfLight     / (kBoltzmann * (TT+1e-6))      ) // damit kein Absturz falls jemand Null fŸr TT eingibt... // B muss mit 100 mulrtipliziert werden, weil SI-Umrechnung erforderlich
		ypw[J] = yptemp
	endfor
pw[0]=pw[1]	// pw[0] existiert nicht, da erstes sinnvolles J'' = 1
ypw[0]=0	
end

function calculateRPositions(we, wexe, B, TT)	// R-Zweig: J -> J+1, erstes sinnvolles J'' = 0
	variable we, wexe, B, TT
	variable J, rtemp, yrtemp
	variable nu_0 = we - 2 * wexe
	make/o/N=100 rw
	duplicate/o rw yrw
	for (J=0; J<100; J+=1)
		rtemp =  nu_0 + 2 * B * J + 2 * B
		rw[J] = rtemp
		yrtemp = (2*J+2) * exp( -(100*B)*(J)*(J+1)*kPlanck * kSpeedOfLight      / (kBoltzmann * (TT+1e-6))      )  
		yrw[J] = yrtemp

	endfor
end


function ZweiInEins(w1,w2,w3,w4)
wave w1,w2	// Positionen des P-Zweiges (w1) und des R-Zweiges (w2)
wave w3,w4	// Positionen des R-Zweiges (w3) und des R-Zweiges (w4)
variable numPoints = numpnts(w1) + numpnts(w2)
variable/G gMinValue, gMaxValue // kleinste u. grš§te x-Positionen, global, da weiterverwendet woanders
Concatenate/NP/O {w1,w2},XPRW
Concatenate/NP/O {w3,w4},YPRW
// Sicherstellen dass sortiert, besser nachsortieren:
sort xprw, xprw,yprw
WaveStats/Q XPRW
gMinValue = V_min
gMaxValue = V_max

end

function LinesToSpecRotVib(xw,yw, destwavestart,destwavestop)
	wave xw,yw
	variable destwavestart, destwavestop
	variable numpoints=numpnts(xw)
	string destwavestr = nameofwave(yw)
	variable numptsfactor = 100
	destwavestr += "_lin"
	make/o/N=(numptsfactor  *  numpoints) $destwavestr
	wave ww = $destwavestr
	ww = 0
	setscale x,destwavestart, destwavestop, ww
	variable j
	for(j = 0; j<numpoints; j+=1)
		ww[x2pnt(ww,xw[j])]=yw[j]
	endfor
end



function morsefit(w,xx): FitFunc	// fŸr HF
	wave w
	variable xx	
	// w[0] = we		// cm-1
	// w[1] = wexe // cm-1
	// w[2] = r_0 // cm
	// w[3] = y_0	// y-Offset, weil das Potentialminimum  nicht genau bei Null liegt...
	variable we = w[0]				//Harmonische Konstante
	variable wexe = w[1]			//AnharmonizitŠtskonstante
	variable r_0 = w[2]			// Gleichgewichtsabstand in cm (also das Resultat ist irgendetwas mit 10^{-8} cm
	variable De = we^2/(4*wexe)	// Dissoziationsenergie in cm-1
	variable mu = (16*12)/(16+12)			// reduzierte Masse in amu !!!!!!!!!!!!!! fŸr HCl bzw. HF, als Zahlenwert einzutragen
	variable beta = 1.2177e7 * we * sqrt(mu/De) // Herzberg(I): III-100
	variable y_0 = w[3]
	return De * (1 - exp(-beta*(xx-r_0)))^2 + y_0
end



function morsefunction(xx,we, wexe, m1, m2,r0)
	variable xx, we,wexe,m1,m2,r0 // xx: x of wave (new syntax)

	variable De = we^2/(4*wexe)
	variable mu = m1*m2/(m1+m2)
	variable beta = 1.2177e7 * we * sqrt(mu/De) // Herzberg(I): III-100
	return De * (1 - exp(-beta*(xx-r0)))^2
end

// we und wexe werden in cm-1 an die function uebergeben.
// m1 und m2 sind in atomaren Masseneinheiten einzugeben, also z.B.
// N: 14 uebergeben.
// der Abstand r (bzw. x) wird in cm angegeben, also der Bereich liegt um 0...3e-8 cm



function getB_rot(m1, m2, r0)	// m1, m2 in amu, r0 in Angstrom
variable m1, m2, r0
variable amu = 1.66053886e-27	//kg
variable B_rot
m1 *= amu
m2 *= amu
r0 *= 1e-10
variable reduzMasse = m1*m2/(m1+m2)
variable momentOfInertia =  reduzMasse * r0 * r0
B_rot = kPlanck/(8 * pi^2 * kSpeedOfLight * momentOfInertia  )	// in m-1
B_rot /= 100	// jetzt in cm-1
print "B_rot =", B_rot, " cm-1"
end