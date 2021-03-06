!-------------------------------------------------------------------------------
! (c) The copyright relating to this work is owned jointly by the Crown,
! Met Office and NERC 2014.
! However, it has been created with the help of the GungHo Consortium,
! whose members are identified at https://puma.nerc.ac.uk/trac/GungHo/wiki
!-------------------------------------------------------------------------------
! Author R. Ford STFC Daresbury Lab

program single_set

  ! Description: single infrastructure set routine specified in an invoke call
  use inf,      only: field_type
  implicit none
  type(field_type) :: one

  call invoke(                                           &
       set(one,1.0)                                      &
       )

end program single_set
