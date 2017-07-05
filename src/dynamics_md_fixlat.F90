!**********************************************************************************************
subroutine MD_fixlat(parini,latvec_in,xred_in,fcart_in,strten_in,vel_in,etot_in,iprec,counter,folder)
 use global, only: target_pressure_habohr,target_pressure_gpa,nat,ntypat,znucl,amu,amutmp,typat,ntime_md
 use global, only: char_type,mdmin,dtion_md,units,usewf_md,auto_dtion_md,energy_conservation
 use global, only: nit_per_min,fixat,fixlat,bc
 use defs_basis
 use interface_code
 use mod_parini, only: typ_parini
implicit none
    type(typ_parini), intent(in):: parini
    integer:: iat,iprec,istep
    real(8):: latvec_in(3,3), xred_in(3,nat),fcart_in(3,nat),vel_in(3,nat), strten_in(6), etot_in, counter
    real(8):: rxyz(3,nat),fxyz(3,nat),fxyz_old(3,nat),vxyz(3,nat),amass(nat)
    character(len=4) :: fn4
    real(8) :: e0,at1,at2,at3
    character(40):: filename,folder
    integer :: nummax,nummin, istepnext
    real(8) :: enmin1, enmin2, en0000, econs_max, econs_min, devcon
    logical:: getwfk
    real(8):: pressure,int_pressure_gpa,energy,rkin,rkin_0,dt,dt_ratio
    if((all(fixlat(1:6)).and..not.fixlat(7)).or.bc==2) then
       continue
    else
       write(*,*) "This routine only intended for fixed cell MD calculation"
       stop
    endif
    pressure=target_pressure_habohr
    dt=dtion_md

    !C initialize positions,velocities, forces
    call rxyz_int2cart(latvec_in,xred_in,rxyz,nat)


    !C inner (escape) loop
    nummax=0
    nummin=0
    enmin1=0.d0
    en0000=0.d0
    econs_max=-1.d100
    econs_min=1.d100
    istepnext=5

!Assign masses to each atom (for MD)
    do iat=1,nat
      amass(iat)=amu_emass*amu(typat(iat))
      write(*,'(a,i5,2(1x,es15.7))') " # MD: iat, AMU, EM: ", iat, amu(typat(iat)),amass(iat)
    enddo

!INITIAL STEP, STILL THE SAME STRUCTURE AS INPUT
       getwfk=.false.
       call get_energyandforces_single(parini,latvec_in,xred_in,fcart_in,strten_in,etot_in,iprec,getwfk)
       write(*,*) "Energy",etot_in
       istep=0
       energy=etot_in
       fxyz=fcart_in
       fxyz_old=fcart_in
       vxyz=vel_in
       call elim_fixed_at(nat,vxyz)
       call elim_fixed_at(nat,fxyz)
       call elim_fixed_at(nat,fxyz_old)
       rkin=0.d0
       do iat=1,nat
          rkin=rkin+amass(iat)*(vxyz(1,iat)**2+vxyz(2,iat)**2+vxyz(3,iat)**2)
       enddo
       rkin=rkin*.5d0
       rkin_0=rkin
       int_pressure_gpa=1.d0/3.d0*(strten_in(1)+strten_in(2)+strten_in(3))*HaBohr3_GPa
       if(parini%verb.gt.0) then
       write(*,'(a,i5,1x,3(1x,1pe17.10),3(1x,i2))') ' # MD: it,energy,ekinat,pressure,nmax,nmin,mdmin ',&
             &istep,energy,rkin,int_pressure_gpa,nummax,nummin,mdmin
       write(fn4,'(i4.4)') istep
       filename=trim(folder)//"posmd."//fn4//".ascii"
       units=units
       write(*,*) "# Writing the positions in MD:",filename
       call write_atomic_file_ascii(parini,filename,nat,units,xred_in,latvec_in,fcart_in,strten_in,&
            &char_type(1:ntypat),ntypat,typat,fixat,fixlat,etot_in,pressure,etot_in,etot_in)
       endif
!*********************************************************************
    e0 = etot_in

    md_loop: do istep=1,ntime_md

!C      Evolution of the system according to 'VELOCITY VERLET' algorithm
       do iat=1,nat
          rxyz(:,iat)=rxyz(:,iat)+dt*vxyz(:,iat)
          rxyz(:,iat)=rxyz(:,iat)+0.5d0*dt*dt/amass(iat)*fxyz(:,iat)
         ! call daxpy(3*nat,dt,vxyz(1,1),1,rxyz(1,1),1)
         ! call daxpy(3*nat,0.5d0*dt*dt,fxyz(1,1),1,rxyz(1,1),1)
       enddo


       enmin2=enmin1
       enmin1=en0000
       if(istep.ne.1.and.usewf_md) then
           getwfk=.true.
       else
           getwfk=.false.
       endif
       call rxyz_cart2int(latvec_in,xred_in,rxyz,nat)
       call get_energyandforces_single(parini,latvec_in,xred_in,fcart_in,strten_in,etot_in,iprec,getwfk)
       fxyz=fcart_in
       energy=etot_in
!       call call_bigdft(runObj, outs, nproc,iproc,infocode)
       en0000=energy-e0
       if (istep >= 3 .and. enmin1 > enmin2 .and. enmin1 > en0000)  nummax=nummax+1
       if (istep >= 3 .and. enmin1 < enmin2 .and. enmin1 < en0000)  nummin=nummin+1
       do iat=1,nat
          at1=fxyz(1,iat)
          at2=fxyz(2,iat)
          at3=fxyz(3,iat)
          !C Evolution of the velocities of the system
!          if (.not. atoms%lfrztyp(iat)) then
             vxyz(1,iat)=vxyz(1,iat) + (.5d0*dt/amass(iat)) * (at1 + fxyz_old(1,iat))
             vxyz(2,iat)=vxyz(2,iat) + (.5d0*dt/amass(iat)) * (at2 + fxyz_old(2,iat))
             vxyz(3,iat)=vxyz(3,iat) + (.5d0*dt/amass(iat)) * (at3 + fxyz_old(3,iat))
!          end if
          !C Memorization of old forces
          fxyz_old(1,iat) = at1
          fxyz_old(2,iat) = at2
          fxyz_old(3,iat) = at3
       end do
       call elim_fixed_at(nat,vxyz)
       call elim_fixed_at(nat,fxyz)
       call elim_fixed_at(nat,fxyz_old)
       rkin=0.d0
       do iat=1,nat
          rkin=rkin+amass(iat)*(vxyz(1,iat)**2+vxyz(2,iat)**2+vxyz(3,iat)**2)
       enddo
       rkin=rkin*.5d0

!!!   if (atoms%astruct%geocode == 'S') then 
!!!      call fixfrag_posvel_slab(iproc,atoms%astruct%nat,rcov,atoms%astruct%rxyz,vxyz,2)
!!!   else if (atoms%astruct%geocode == 'F') then
!!!     if (istep == istepnext) then 
!!!           call fixfrag_posvel(iproc,atoms%astruct%nat,rcov,atoms%astruct%rxyz,vxyz,2,occured)
!!!        if (occured) then 
!!!          istepnext=istep+4
!!!        else
!!!          istepnext=istep+1
!!!        endif
!!!     endif
!!!   endif
       econs_max=max(econs_max,rkin+energy)
       econs_min=min(econs_min,rkin+energy)
       devcon=econs_max-econs_min
       counter=real(istep,8)
       int_pressure_gpa=1.d0/3.d0*(strten_in(1)+strten_in(2)+strten_in(3))*HaBohr3_GPa
       if(parini%verb.gt.0) then
       write(*,'(a,i5,1x,3(1x,1pe17.10),3(1x,i2))') ' # MD: it,energy,ekinat,pressure,nmax,nmin,mdmin ',&
             &istep,energy,rkin,int_pressure_gpa,nummax,nummin,mdmin
       write(fn4,'(i4.4)') istep
       filename=trim(folder)//"posmd."//fn4//".ascii"
       units=units
       write(*,*) "# Writing the positions in MD: ",filename
       call write_atomic_file_ascii(parini,filename,nat,units,xred_in,latvec_in,fcart_in,strten_in,&
            &char_type(1:ntypat),ntypat,typat,fixat,fixlat,etot_in,pressure,etot_in,etot_in)
       endif
       if (nummin.ge.mdmin) then
          if (nummax.ne.nummin) &
               write(*,*) '# WARNING: nummin,nummax',nummin,nummax
             write(*,*) " MD finished: exiting!"
          exit md_loop
       endif

    end do md_loop
    !C MD stopped, now do relaxation

    !  if (iproc == 0) write(67,*) 'EXIT MD',istep
    
    ! adjust time step to meet precision criterion
!Minimum number of steps per crossed minimum is 15, average should be nit_per_min
 if(auto_dtion_md) then
    if(energy_conservation) then
        devcon=devcon/(3*nat-3)
        if (devcon/rkin_0.lt.1.d-2) then
           dtion_md=dtion_md*1.05d0
        else
           dtion_md=dtion_md*(1.d0/1.05d0)
        endif
      write(*,'(a,es10.2,es10.2,a,es10.2)') " # MD: energy conservation :",devcon,rkin_0,&
      &", dtion_md set to: ",dtion_md
    else 
       dt_ratio=real(istep,8)/real(nummin,8) 
       if(dt_ratio.lt.real(nit_per_min,8)) then
         dtion_md=dtion_md*1.d0/1.1d0
       else
         dtion_md=dtion_md*1.1d0 
       endif
       dtion_md=min(dtion_md,dt*dt_ratio/15.d0)
       write(*,'(3(a,es10.2))') " # MD: steps per minium: ",dt_ratio,&
      &", dtion_md set to: ",dtion_md,", upper boundary: ",dt*dt_ratio/15.d0 
     endif
  endif
   

!MD stopped, now do relaxation
     write(*,'(a,i5,es15.7)') ' # EXIT MD ',istep,etot_in
    
  END SUBROUTINE
